#!/usr/bin/env bash
# Content-addressed result cache for gate falsifiers (source this file).
#
# A falsifier arm compiles Lean for real; the answer (exit code + output) depends only on its inputs. An entry is
# stored under sha256(every input of that arm), so the same inputs are never compiled twice. Rules:
#   - An entry records ONLY what a real run returned: the cache layer never invents, edits or widens a result.
#     The caller still judges the stored exit code and output with the arm's own verdict logic, every time.
#   - Fail closed: an entry that is missing, unreadable, truncated, of another key, with a changed exit code or
#     output, or with a wrong checksum is ignored; the caller recomputes and overwrites it.
#   - The cache lives outside the git tree (ADS_GATE_CACHE, default ${XDG_CACHE_HOME:-$HOME/.cache}/ads-gate-cache),
#     so a clean checkout stays clean. ADS_GATE_CACHE_OFF=1 neither reads nor writes it.
#
# Entry file <key>.entry, text:   ADS-GATE-CACHE v1 / key <hex> / rc <int> / outsha <hex> / --- / <output> / sum <hex>
# where sum = sha256 of every byte above the sum line.
#
# API:  rc_key            reads components on stdin, prints the 64-hex key
#       rc_get <key>      sets RC_RC and RC_OUT and returns 0 on a valid entry, 1 otherwise (always safe to recompute)
#       rc_put <key> <rc> <out>   stores a real result (best effort; a failed write is not an error)

RC_DIR="${ADS_GATE_CACHE:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/ads-gate-cache}"
RC_OFF="${ADS_GATE_CACHE_OFF:-0}"

rc_key() { sha256sum | cut -d" " -f1; }
# ADS_GATE_CACHE_TRACE=<file>: append one "hit|miss <key>" line per lookup (the falsifiers prove a hit or a miss from it)
rc_trace() { [ -z "${ADS_GATE_CACHE_TRACE:-}" ] || printf "%s %s\n" "$1" "$2" >> "$ADS_GATE_CACHE_TRACE"; }

_rc_get() {
  RC_RC=""; RC_OUT=""
  [ "$RC_OFF" = 1 ] && return 1
  local key="$1" f="$RC_DIR/$1.entry" body sum h1 h2 h3 h4 h5 rc osum
  case "$key" in *[!0-9a-f]*|'') return 1;; esac
  [ "${#key}" -eq 64 ] && [ -f "$f" ] && [ -r "$f" ] || return 1
  sum="$(tail -n 1 "$f" 2>/dev/null)" || return 1
  case "$sum" in "sum "[0-9a-f]*) sum="${sum#sum }";; *) return 1;; esac
  [ "$(head -n -1 "$f" 2>/dev/null | sha256sum | cut -d' ' -f1)" = "$sum" ] || return 1
  { read -r h1 && read -r h2 && read -r h3 && read -r h4 && read -r h5; } < "$f" || return 1
  [ "$h1" = "ADS-GATE-CACHE v1" ] && [ "$h2" = "key $key" ] && [ "$h5" = "---" ] || return 1
  rc="${h3#rc }"; osum="${h4#outsha }"
  [ "$h3" = "rc $rc" ] && [ "$h4" = "outsha $osum" ] || return 1
  case "$rc" in ''|*[!0-9]*) return 1;; esac
  body="$(tail -n +6 "$f" | head -n -1)" || return 1
  [ "$(printf '%s\n' "$body" | sha256sum | cut -d' ' -f1)" = "$osum" ] || return 1
  touch "$f" 2>/dev/null; RC_RC="$rc"; RC_OUT="$body"; return 0
}

rc_put() {
  [ "$RC_OFF" = 1 ] && return 0
  local key="$1" rc="$2" out="$3" tmp f="$RC_DIR/$1.entry" s
  (umask 077; mkdir -p "$RC_DIR") 2>/dev/null || return 0
  tmp="$(mktemp "$RC_DIR/.tmp.XXXXXX" 2>/dev/null)" || return 0
  {
    printf 'ADS-GATE-CACHE v1\nkey %s\nrc %s\noutsha %s\n---\n%s\n' "$key" "$rc" "$(printf '%s\n' "$out" | sha256sum | cut -d' ' -f1)" "$out"
  } > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 0; }
  s="$(sha256sum < "$tmp" | cut -d' ' -f1)"
  printf 'sum %s\n' "$s" >> "$tmp" 2>/dev/null && mv -f "$tmp" "$f" 2>/dev/null || rm -f "$tmp"
  return 0
}

# Prune entries not used for 30 days and stray temp files older than a day (best effort).
rc_prune() {
  [ "$RC_OFF" = 1 ] && return 0
  find "$RC_DIR" -maxdepth 1 -name '*.entry' -mtime +30 -delete 2>/dev/null || true
  find "$RC_DIR" -maxdepth 1 -name '.tmp.*' -mtime +1 -delete 2>/dev/null || true
  return 0
}

# rc_judge <key> <arm> <pass|red> <pat> <runner...>: judge one falsifier arm and print its line(s); returns 0 when the arm is ok.
# A hit replays what a real run returned; a miss runs <runner> (its output and exit code are the real result). Either way the arm's
# verdict is decided from that result HERE, and only an arm judged ok has its result stored, after the verdict and not before.
# A result that fails its verdict is never stored, so no other arm or later run can read a result nobody judged.
# The key must already carry the arm id and every input of the arm (callers hash both); one arm never shares a key with another.
rc_judge() {
  local key="$1" n="$2" want="$3" pat="$4" out rc hit=0 ok=0; shift 4
  if rc_get "$key"; then out="$RC_OUT"; rc="$RC_RC"; hit=1; else out="$("$@" 2>&1)"; rc=$?; fi
  if [ "$want" = pass ]; then
    if [ "$rc" -eq 0 ]; then ok=1; else echo "  $n FAIL (rc=$rc): $out" | tail -8; fi
  else
    if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -qE -- "$pat"; then ok=1; else echo "  $n FAIL (rc=$rc, wanted RED matching '$pat'): $out" | tail -8; fi
  fi
  [ "$ok" -eq 1 ] || return 1
  [ "$hit" -eq 1 ] || rc_put "$key" "$rc" "$out"
  echo "  $n ok"; return 0
}

# ---- per-test olean cache (check-lean-fn-coverage.sh, TEST_CACHE) ----
# One directory per input key: <cache>/<key>/{olean,sum}. The key is the sha256 of the module name, the test source and a hash of
# the library the test is compiled against, so a test is reused only against the very inputs it was compiled with. An entry is
# built in a temp directory and published by one rename after the compile has succeeded, so a reader sees all of it or none of it;
# an entry whose olean does not match its checksum is removed and recompiled.
tc_ikey() { # <module> <source file> <library hash>
  { printf '%s\n%s\n' "$1" "$3"; cat "$2"; } | sha256sum | cut -d' ' -f1; }
tc_get() { # <cache dir> <key> <dest olean>: 0 and the olean copied to <dest> on an intact entry, 1 otherwise
  local d="$1/$2" want got
  [ -f "$d/olean" ] && [ -f "$d/sum" ] || return 1
  want="$(cat "$d/sum" 2>/dev/null)"; got="$(sha256sum < "$d/olean" 2>/dev/null | cut -d' ' -f1)"
  if [ -z "$want" ] || [ "$want" != "$got" ]; then rm -rf "${d:?}" 2>/dev/null; return 1; fi
  mkdir -p "$(dirname "$3")" && cp "$d/olean" "$3.tc.$$" && [ "$(sha256sum < "$3.tc.$$" | cut -d' ' -f1)" = "$want" ] && mv -f "$3.tc.$$" "$3" || { rm -f "$3.tc.$$"; return 1; }
}
tc_put() { # <cache dir> <key> <olean>: publish a compiled olean (best effort; the first writer of a key wins)
  local tmp
  mkdir -p "$1" 2>/dev/null && tmp="$(mktemp -d "$1/.tmp.XXXXXX" 2>/dev/null)" || return 0
  cp "$3" "$tmp/olean" 2>/dev/null && sha256sum < "$tmp/olean" | cut -d' ' -f1 > "$tmp/sum" || { rm -rf "${tmp:?}"; return 0; }
  mv -T "$tmp" "$1/$2" 2>/dev/null || rm -rf "${tmp:?}"
  return 0
}

rc_get() { if [ "$RC_OFF" = 1 ]; then RC_RC=""; RC_OUT=""; return 1; fi; if _rc_get "$1"; then rc_trace hit "$1"; return 0; fi; RC_RC=""; RC_OUT=""; rc_trace miss "$1"; return 1; }

# ---- inputs of the Lean fn-coverage check (shared by its falsifier and its cached gate run) ----
# hash_tree <dir> [find args]: "sha256 path" for every file, sorted.
hash_tree() { (cd "$1" && find . -type f "${@:2}" | LC_ALL=C sort | while IFS= read -r f; do printf '%s %s\n' "$(sha256sum < "$f" | cut -d' ' -f1)" "$f"; done); }
# rc_lean_inputs <repo> <real package> [extra files]: one sha256 over everything a run of check-lean-fn-coverage.sh can depend on:
# the Lean toolchain id and the manifest, every source and registry of the real package (not .lake), the built library oleans it
# loads, the datasets the tests read, the check, the plot scripts, this helper, and the extra files (the calling script).
rc_lean_inputs() {
  local here="$1" real="$2"; shift 2
  {
    lean --version 2>&1; cat "$real/lean-toolchain" "$real/lake-manifest.json" "$real/lakefile.toml"
    hash_tree "$real" -not -path './.lake/*' -not -path './plot.*' -not -name planted.svg
    [ -d "$real/.lake/build/lib/lean" ] && hash_tree "$real/.lake/build/lib/lean" -name '*.olean'
    hash_tree "$here/datasets"
    sha256sum "$here/scripts/check-lean-fn-coverage.sh" "$here/scripts/result-cache.sh" "$here/scripts/lean-plot.sh" "$here/scripts/falsify-lean-plot.sh" "$@"
  } 2>&1 | sha256sum | cut -d' ' -f1
}
