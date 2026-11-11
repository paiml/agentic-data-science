#!/usr/bin/env bash
# Lean has no line-coverage tool, so the substitute receipt is: every function and every refusal path
# in the Lean demo and plot code is reached by a test or a demo that runs (ads#130, part of #129).
# The check reads the COMPILED code, not the text: lean/AgenticDS/scripts/FnCoverage.lean loads the
# .olean of every module under lean/AgenticDS/AgenticDS (the library and every Examples/ module) and of
# every test under AgenticDSTest, then walks, from the `main` of each test and each demo, the constants
# each elaborated definition uses. A name inside a string or a comment, or a function nobody calls, is
# not coverage.
#   FUNCTIONS: every user-written definition of the library must be reached from a `main`. An
#     unreached one is RED. So is a test definition that no test `main` reaches (a test that never runs).
#   REFUSALS: a refusal path is an elaborated term that throws an `IO.userError`, or builds `none` in a
#     function whose result is an `Option`. Each needs a row in lean/AgenticDS/scripts/refusals.tsv naming
#     the test file and the label the test carries; the file must carry the label. A site with no row is
#     RED, and so is a row with no site.
#   PIN: the registry carries `#pin ndef=N nsites=M`; the counts the walker finds must equal it.
#   PLOT SCRIPT: every `exit 1|2` and `return 1` in scripts/lean-plot.sh needs a planted arm in
#     scripts/falsify-lean-plot.sh (rows `lean-plot.sh` in refusals.tsv, needle = the arm id).
# usage: check-lean-fn-coverage.sh [--list]     --list prints the function -> entry mapping
# env: LEAN_PKG (package under test), LEAN_REAL (package whose build supplies the oleans; default LEAN_PKG)
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
pkg="${LEAN_PKG:-$here/lean/AgenticDS}"
real="${LEAN_REAL:-$pkg}"
reg="${REFUSALS:-$pkg/scripts/refusals.tsv}"
plot="${LEAN_PLOT:-$here/scripts/lean-plot.sh}"
arms="${LEAN_PLOT_ARMS:-$here/scripts/falsify-lean-plot.sh}"
list=0; [ "${1:-}" = "--list" ] && list=1
fail=0
red() { echo "RED: $*"; fail=1; }
[ -d "$pkg/AgenticDS" ] && [ -d "$pkg/AgenticDSTest" ] || { echo "RED: no Lean package at $pkg"; exit 1; }
[ -s "$reg" ] || { echo "RED: refusal registry $reg missing or empty"; exit 1; }
compgen -G "$pkg/AgenticDS/*.lean" >/dev/null || { echo "RED: found no function (no .lean file in $pkg/AgenticDS)"; exit 1; }
export PATH="$HOME/.elan/bin:$PATH"
if [ "$real" = "$pkg" ]; then (cd "$real" && lake build AgenticDS >/dev/null 2>&1) || { echo "RED: lake build AgenticDS failed"; exit 1; }; fi
lib="$real/.lake/build/lib/lean"
[ -d "$lib/AgenticDS" ] || { echo "RED: no built library at $lib/AgenticDS"; exit 1; }

# An overlay of symlinks to the real oleans; a module whose source differs from the real one (a planted
# change), or has no olean (Examples files lake does not build, every test), is compiled over its link.
ov="$(mktemp -d)"; trap 'rm -rf "${ov:?}"' EXIT
cp -rs "$lib/AgenticDS" "$ov/AgenticDS"; ln -s "$lib/AgenticDS.olean" "$ov/AgenticDS.olean"
lp="$(cd "$real" && lake env printenv LEAN_PATH)"
export LEAN_PATH="$ov:$lp"
compile() { # <source> <module path under the overlay, no extension>
  rm -f "${ov:?}/$2.olean"; mkdir -p "$(dirname "$ov/$2.olean")"
  (cd "$pkg" && lean -o "$ov/$2.olean" "$1") >"$ov/$(echo "$2" | tr / _).log" 2>&1 || { echo "RED: $1 does not compile: $(head -3 "$ov/$(echo "$2" | tr / _).log")"; return 1; }
}
cfail=0
# TEST_CACHE (the falsifier sets one directory per arm, never shared): a test compiled before against the same inputs reuses its olean.
# The cache key is the module, its source and a hash of the library it is compiled against (the package's library sources, the built
# library oleans and the Lean version), so an olean is served only for the inputs that produced it; an entry is published after a
# successful compile, by one rename, and is refused when its checksum does not match (scripts/result-cache.sh, tc_*).
# shellcheck source=scripts/result-cache.sh
. "$here/scripts/result-cache.sh"
libhash=""
cached_compile() {
  local c="${TEST_CACHE:-}" k
  if [ -n "$c" ]; then
    k="$(tc_ikey "$2" "$1" "$libhash")"
    if tc_get "$c" "$k" "$ov/$2.olean"; then return 0; fi
  fi
  compile "$1" "$2" || return 1
  [ -z "$c" ] || tc_put "$c" "$k" "$ov/$2.olean"
  return 0
}
[ -z "${TEST_CACHE:-}" ] || libhash="$( { lean --version 2>&1; hash_tree "$pkg/AgenticDS"; hash_tree "$lib" -name '*.olean'; } | sha256sum | cut -d' ' -f1)"
while IFS= read -r f; do
  rel="${f#"$pkg"/}"; rel="${rel%.lean}"
  if [ ! -e "$ov/$rel.olean" ] || ! cmp -s "$f" "$real/$rel.lean" 2>/dev/null; then compile "$f" "$rel" || cfail=1; fi
done < <(find "$pkg/AgenticDS" -name '*.lean' | sort)
mkdir -p "$ov/AgenticDSTest"; pids=()
for f in "$pkg"/AgenticDSTest/*.lean; do
  case "$f" in */PlantedWrongSlope*) continue;; esac
  rel="AgenticDSTest/$(basename "$f" .lean)"
  cached_compile "$f" "$rel" & pids+=($!)
done
for p in "${pids[@]}"; do wait "$p" || cfail=1; done
[ "$cfail" -eq 0 ] || exit 1

runlist="${RUN_LIST:-$pkg/scripts/run-list.tsv}"
[ -s "$runlist" ] || { echo "RED: run list $runlist missing or empty (the gate's test runs; the entry points come from it)"; exit 1; }
modof() { printf '%s' "${1%.lean}" | tr / .; }
lakef="$pkg/lakefile.toml"; [ -f "$lakef" ] || lakef="$real/lakefile.toml"
entries="$( { awk -F'\t' '!/^#/ && NF >= 4 { print $3 }' "$runlist" | sort -u | while IFS= read -r f; do modof "$f"; echo; done; sed -n 's/^root = "\(.*\)"/\1/p' "$lakef"; } | grep . | sort -u | tr '\n' ' ')"
while IFS="$(printf '\t')" read -r rid rmode rfile _; do
  case "$rid" in ''|'#'*) continue;; esac
  [ -f "$pkg/$rfile" ] || red "run list row $rid: file $rfile does not exist"
done < "$runlist"
libs="$(cd "$pkg" && find AgenticDS -name '*.lean' | sort | sed 's|\.lean$||; s|/|.|g' | tr '\n' ' ')"
tests="$(cd "$pkg" && for f in AgenticDSTest/*.lean; do case "$f" in */PlantedWrongSlope*) continue;; esac; basename "$f" .lean | sed 's/^/AgenticDSTest./'; done | tr '\n' ' ')"
# shellcheck disable=SC2086
walkrc=0; walk="$(cd "$real" && lean --run "$real/scripts/FnCoverage.lean" $libs -- $tests -- $entries 2>&1)" || walkrc=$?
[ "$walkrc" -eq 0 ] || { echo "RED: the Lean walker failed (rc $walkrc): $(printf "%s\n" "$walk" | head -5)"; exit 1; }
# Strip the package prefix: module AgenticDS.Csv -> Csv, def AgenticDS.parseRat -> parseRat.
walk="$(printf '%s\n' "$walk" | sed -E 's/^(DEF|SITE|TDEF) AgenticDS\./\1 /; s/^(DEF|SITE|TDEF) ([^ ]+) AgenticDS\./\1 \2 /; s/^(REACH\t)AgenticDS\./\1/; s/^(REACH\t[^\t]+\t)AgenticDS\./\1/')"
[ -z "${WALK_OUT:-}" ] || printf "%s\n" "$walk" > "$WALK_OUT"
for e in $entries; do
  grep -qx "ENTRY $e" <<<"$walk" || red "entry point $e has no main (it is in the run list or the lakefile)"
done
walk="$(printf '%s\n' "$walk" | sed -E 's/^(DEF|SITE|TDEF) AgenticDS\./\1 /; s/^(DEF|SITE|TDEF) ([^ ]+) AgenticDS\./\1 \2 /')"

nentry="$(printf '%s\n' "$walk" | grep -c '^ENTRY ' || true)"
ndef="$(printf '%s\n' "$walk" | grep -c '^DEF ' || true)"
[ "$nentry" -ge 1 ] && [ "$ndef" -ge 1 ] || { echo "RED: found no entry point or no function ($nentry entries, $ndef functions); a coverage check over nothing is no check"; exit 1; }
untested="$(printf '%s\n' "$walk" | awk '$1=="DEF" && $4=="UNTESTED"')"
if [ -n "$untested" ]; then
  printf '%s\n' "$untested" | while read -r _ m n _; do
    echo "RED: function $m.$n has no test (no test or demo main reaches it through the compiled code)"; done
  fail=1
fi
tuntested="$(printf '%s\n' "$walk" | awk '$1=="TDEF" && $4=="UNTESTED"')"
if [ -n "$tuntested" ]; then
  printf '%s\n' "$tuntested" | while read -r _ m n _; do
    echo "RED: test definition $m.$n is never run (no test main reaches it)"; done
  fail=1
fi
nun="$(printf '%s\n' "$untested" | grep -c . || true)"
echo "functions: $((ndef - nun)) of $ndef reached from $nentry entry points"
if [ "$list" -eq 1 ]; then printf '%s\n' "$walk" | awk '$1=="DEF" { printf "  %-16s %-22s %s\n", $2, $3, $4 }'; fi

# Refusal sites, per enclosing definition.
sites="$(printf '%s\n' "$walk" | awk '$1=="SITE" { print $2 "\t" $3 "\t" $4 }' | sort -u)"
nsites="$(printf '%s\n' "$sites" | grep -c . || true)"
pin="$(grep -E '^#pin ' "$reg" | head -1 || true)"
if [ -z "$pin" ]; then red "refusals.tsv has no '#pin ndef=N nsites=M' line"
else
  pd="$(printf '%s\n' "$pin" | sed -n 's/.*ndef=\([0-9]*\).*/\1/p')"; ps="$(printf '%s\n' "$pin" | sed -n 's/.*nsites=\([0-9]*\).*/\1/p')"
  [ "$pd" = "$ndef" ] || red "pin: ndef is pinned at ${pd:-?} but the walker found $ndef functions"
  [ "$ps" = "$nsites" ] || red "pin: nsites is pinned at ${ps:-?} but the walker found $nsites refusal sites"
fi
rows="$(awk -F'\t' '!/^#/ && NF >= 5 && $1 != "lean-plot.sh"' "$reg")"
unreg="$(printf '%s\n' "$sites" | while IFS="$(printf '\t')" read -r m n k; do
  [ -n "$m" ] || continue
  printf '%s\n' "$rows" | awk -F'\t' -v m="$m" -v n="$n" -v k="$k" '$1==m && $2==n && $3==k { f=1 } END { exit !f }' \
    || echo "RED: refusal path $m.$n ($k) has no row in refusals.tsv (and so no test)"
done)"
if [ -n "$unreg" ]; then printf '%s\n' "$unreg"; fail=1; fi
# Run each run-list row a registry row names, once, in the overlay; keep its output and exit code.
rd="$ov/runs"; mkdir -p "$rd"; pids=()
runrow() { # <id>
  local id="$1" mode file arg needle cs rc=0
  IFS="$(printf '\t')" read -r _ mode file arg needle < <(awk -F'\t' -v id="$id" '$1==id' "$runlist")
  if [ "$mode" = stub ]; then
    cs="$rd/$id.stub"; mkdir -p "$cs"; printf '#!/bin/sh\n[ "$1" = "-version" ] && exit 0\necho stub-convert-failed >&2\nexit 1\n' > "$cs/convert"; chmod +x "$cs/convert"
    (cd "$pkg" && PATH="$cs:$PATH" lean --run "$file" "$arg") >"$rd/$id.out" 2>&1 || rc=$?; rm -f "$pkg/plot.svg"
  else
    (cd "$pkg" && lean --run "$file" "$arg") >"$rd/$id.out" 2>&1 || rc=$?
  fi
  echo "$rc" > "$rd/$id.rc"
}
for id in $(awk -F'\t' '!/^#/ && NF >= 5 && $1 != "lean-plot.sh" { print $4 }' "$reg" | sort -u); do
  awk -F'\t' -v id="$id" '$1==id { f=1 } END { exit !f }' "$runlist" && { runrow "$id" & pids+=($!); }
done
for p in "${pids[@]:-}"; do [ -n "$p" ] && wait "$p"; done
nrows=0
while IFS="$(printf '\t')" read -r m n k rid label; do
  [ -n "$m" ] || continue; nrows=$((nrows + 1))
  printf '%s\n' "$sites" | awk -F'\t' -v m="$m" -v n="$n" -v k="$k" '$1==m && $2==n && $3==k { f=1 } END { exit !f }' \
    || { red "registry row $m $n $k names no refusal site in the library (stale row)"; continue; }
  line="$(awk -F'\t' -v id="$rid" '$1==id' "$runlist")"
  [ -n "$line" ] || { red "refusal $m.$n ($k): run $rid is not in the run list"; continue; }
  mode="$(printf '%s' "$line" | cut -f2)"; rfile="$(printf '%s' "$line" | cut -f3)"; E="$(modof "$rfile")"
  [ -f "$rd/$rid.rc" ] || { red "refusal $m.$n ($k): run $rid produced no result"; continue; }
  printf '%s\n' "$walk" | awk -F'\t' -v m="$m" -v n="$n" -v e="$E" '$1=="REACH" && $2==m && $3==n && $4==e { f=1 } END { exit !f }' \
    || { red "refusal $m.$n ($k): the run $rid (entry $E) never reaches the site"; continue; }
  rc="$(cat "$rd/$rid.rc")"; out="$(cat "$rd/$rid.out")"
  if [ "$mode" = ok ]; then
    [ "$rc" -eq 0 ] || { red "refusal $m.$n ($k): run $rid exits $rc: $(printf '%s\n' "$out" | tail -2)"; continue; }
    [ "$label" = "refusal $m.$n $k" ] || { red "refusal $m.$n ($k): label '$label' is not 'refusal $m.$n $k'"; continue; }
    labs="$(printf '%s\n' "$walk" | awk -F'\t' -v e="$E" -v c="AgenticDS.$n" -v c2="$n" -v p="$label" '$1=="PAIR" && $2==e && ($4==c || $4==c2) && index($3, p)==1 { print $3 }' | sort -u)"
    [ -n "$labs" ] || { red "refusal $m.$n ($k): no check in $E carries the label '$label' paired with the call to $n"; continue; }
    printf '%s\n' "$labs" | while IFS= read -r l; do
      grep -qxF -- "ok $l" <<<"$out" || echo "RED: refusal $m.$n ($k): the run $rid never printed 'ok $l'"
    done > "$rd/miss.txt"
    if [ -s "$rd/miss.txt" ]; then cat "$rd/miss.txt"; fail=1; fi
  else
    [ "$rc" -ne 0 ] || { red "refusal $m.$n ($k): run $rid no longer fails"; continue; }
    grep -qF -- "$label" <<<"$out" || red "refusal $m.$n ($k): run $rid failed without '$label': $(printf '%s\n' "$out" | tail -3)"
  fi
done <<EOT
$rows
EOT
echo "refusal paths (library): $nsites sites, $nrows registry rows"

# lean-plot.sh: every refusal exit needs a planted arm.
[ -f "$plot" ] && [ -f "$arms" ] || { echo "RED: $plot or $arms missing"; exit 1; }
pexits="$(grep -cE 'exit [12]|return 1' "$plot" || true)"
prows="$(awk -F'\t' '!/^#/ && $1 == "lean-plot.sh" && NF >= 4' "$reg")"
np="$(printf '%s\n' "$prows" | grep -c . || true)"
[ "$pexits" -eq "$np" ] || red "lean-plot.sh has $pexits refusal exits but refusals.tsv has $np rows for it"
while IFS="$(printf '\t')" read -r _ marker tf needle; do
  [ -n "$marker" ] || continue
  grep -qF -- "$marker" "$plot" || red "lean-plot.sh: no refusal carries '$marker' (stale row)"
  grep -qF -- "$needle" "$arms" || red "lean-plot.sh refusal '$marker': $tf has no arm '$needle'"
done <<EOF
$prows
EOF
echo "plot refusals (lean-plot.sh): $pexits exits, $np planted-arm rows"
if [ "$fail" -eq 0 ]; then echo "lean fn coverage OK"; else exit 1; fi
