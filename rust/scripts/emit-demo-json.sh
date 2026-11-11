#!/usr/bin/env bash
# emit-demo-json.sh OUT.json: one demo row per rust/term-demos/<id>.cmds, in the same row shape as the Lean emitter
# (lean/AgenticDS/scripts/emit-term-demos.sh): {id:"term-<file stem>", command, commands[], exit, stdout, stdout_sha256, plots:[]}.
#
# INPUT: <id>.cmds holds the lines a terminal session types, one per Enter, and nothing else. The id is the opaque file
# stem. <id>.cwd (one line, relative to the repository root, default ".") is where the session starts; term-demos/env
# holds the fixed session environment (KEY=VALUE lines). A typed line may be run only once: nothing is added to it.
# SESSION: every file runs in ONE bash under a 93x25 pty (util-linux `script`), one command at a time (lines are joined
# until `bash -n` parses them), shown as an interactive shell shows it ("$ " first line, "> " continuation lines).
# stdout is the session transcript with ANSI and CR stripped and the harness timing (`; finished in 1.23s`) pinned to 0.00s,
# and the bench example's measured `polars|btreemap: N ms` lines pinned to 0.000000, so a rerun hashes the same; env sets RUST_TEST_THREADS=1 (fixed test order) and cargo quiet/no progress (no timing lines). The session runs under `set -o pipefail`.
# GUARDS (fail closed, no OUT file is written, a stale OUT is removed first): no .cmds files; an id that is not
# [a-z0-9]+ or that repeats (compared case-folded); a .cmds with no command line; a command not found or not executable
# (126/127); a session that exits non-zero or times out (124); a transcript that does not show every command it was
# given; for a session that runs `cargo test`: no `test result:` line, a failed or ignored test, or passed == 0.
# The file carries the commit; CI attests it with actions/attest-build-provenance.
# ENV: ADS_ROOT (repo root), ADS_TERM_DIR (default rust/term-demos), ADS_WARM (command run first, in the crate dir,
# its output not recorded: builds the crate so a recorded session shows no compile lines), TERM_DEMO_TIMEOUT_S (2400).
# PATH, CARGO_HOME, RUSTUP_HOME and CARGO_TARGET_DIR pass through from the caller; everything else comes from the env file.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT=${1:?usage: emit-demo-json.sh OUT.json}
ROOT=${ADS_ROOT:-$ROOT}
DIR=${ADS_TERM_DIR:-$ROOT/rust/term-demos}
export ADS_ROOT=$ROOT
rm -f "${OUT:?}" "${OUT:?}.tmp"
for t in jq perl script; do command -v "$t" >/dev/null || { echo "FAIL $t not on PATH" >&2; exit 2; }; done
[ -d "$DIR" ] || { echo "FAIL no $DIR" >&2; exit 1; }
shopt -s nullglob
cmds=("$DIR"/*.cmds)
[ ${#cmds[@]} -gt 0 ] || { echo "FAIL no $DIR/*.cmds (a row comes from a typed-lines file)" >&2; exit 1; }
seen=" "
# duplicates first, over every file, so the verdict does not depend on glob order (locale)
for c in "${cmds[@]}"; do
  id=$(basename "$c" .cmds); low=$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]')
  case "$seen" in *" $low "*) echo "FAIL duplicate id $id" >&2; exit 1;; esac
  seen="$seen$low "
done
for c in "${cmds[@]}"; do
  id=$(basename "$c" .cmds)
  [[ "$id" =~ ^[a-z0-9]+$ ]] || { echo "FAIL id '$id' is not [a-z0-9]+" >&2; exit 1; }
  grep -qE '[^[:space:]]' "$c" || { echo "FAIL $id: .cmds has no command line" >&2; exit 1; }
done
work=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-$HOME}}/term-demos.XXXXXX")
[ -n "${TERM_DEMO_KEEP:-}" ] || trap 'rm -rf "${work:?}"' EXIT
mkdir -p "$work/home"
envv=()
if [ -f "$DIR/env" ]; then mapfile -t envv < <(grep -vE '^\s*(#|$)' "$DIR/env"); fi
envv+=("HOME=$work/home" "PATH=$PATH" "CARGO_HOME=${CARGO_HOME:-$HOME/.cargo}" "RUSTUP_HOME=${RUSTUP_HOME:-$HOME/.rustup}")
[ -z "${CARGO_TARGET_DIR:-}" ] || envv+=("CARGO_TARGET_DIR=$CARGO_TARGET_DIR")
strip() { perl -pe 's/\e\][^\a\e]*(\a|\e\\)//g; s/\e\[[0-?]*[ -\/]*[@-~]//g; s/\e[()][A-Z0-9]//g; s/\e[=>]//g; s/\r//g'; }
cat > "$work/run.sh" <<'RUN'
stty cols 93 rows 25 2>/dev/null
PS1='$ '
set -o pipefail
__b=""; __p=0   # __p = status of the previous command, restored before each eval
while IFS= read -r -u 3 __l || [ -n "$__l" ]; do
  __b=${__b:+$__b$'\n'}$__l
  bash -n <<<"$__b" 2>/dev/null || continue
  if [ -n "${ECHO_ONLY:-}" ]; then printf '%s\n' "$__b" | sed '1s/^/$ /; 2,$s/^/> /'; printf '\0'; __b=""; continue; fi
  printf '%s\n' "$__b" | sed '1s/^/$ /; 2,$s/^/> /'
  (exit "$__p"); eval "$__b"; __r=$?; __p=$__r; __b=""
  case $__r in 126|127) echo "term-demo: command not runnable (exit $__r)" >&2; exit "$__r";; esac
done 3< "$1"
[ -z "$__b" ] || { printf 'term-demo: unparsed command at end of file:\n%s\n' "$__b" >&2; exit 2; }
RUN
crate="$ROOT/rust/ads-rust"
if [ -n "${ADS_WARM+x}" ]; then warm=$ADS_WARM; else warm='cargo test --locked --offline --no-run && cargo build --locked --offline --examples'; fi
( cd "$crate" 2>/dev/null || cd "$ROOT"; env -i "${envv[@]}" bash --norc --noprofile -c "$warm" ) >"$work/warm.log" 2>&1 </dev/null || { echo "FAIL warm-up failed: $(tail -n 5 "$work/warm.log")" >&2; exit 1; }
rows="$work/rows.jsonl"; : > "$rows"; bad=()
test_facts() { # FILE -> reason on stdout, non-zero when the transcript's test facts are not acceptable
  local f=$1 p fl i
  grep -qE '^test result:' "$f" || { echo "no test result line"; return 1; }
  read -r p fl i < <(grep -E '^test result:' "$f" | awk '{ for (k = 1; k < NF; k++) { if ($(k+1) ~ /^passed/) p += $k; if ($(k+1) ~ /^failed/) fl += $k; if ($(k+1) ~ /^ignored/) i += $k } } END { print p+0, fl+0, i+0 }')
  [ "$fl" -eq 0 ] || { echo "$fl failed"; return 1; }
  [ "$i" -eq 0 ] || { echo "$i ignored (an ignored test is not attested)"; return 1; }
  [ "$p" -gt 0 ] || { echo "passed == 0 (no test ran)"; return 1; }
}
n=0
for c in "${cmds[@]}"; do
  id=$(basename "$c" .cmds)
  cwd=.; [ -f "${c%.cmds}.cwd" ] && cwd=$(head -n 1 "${c%.cmds}.cwd")
  [ -d "$ROOT/$cwd" ] || { echo "FAIL $id: cwd '$cwd' is not a directory" >&2; exit 1; }
  ( cd "$ROOT/$cwd" && env -i "${envv[@]}" timeout "${TERM_DEMO_TIMEOUT_S:-2400}" script -qefc "bash --norc --noprofile $work/run.sh $c" /dev/null ) \
    > "$work/$id.raw" 2>&1 </dev/null && rc=0 || rc=$?
  strip < "$work/$id.raw" | sed -E "s/; finished in [0-9.]+s/; finished in 0.00s/; s/^( *(polars|btreemap): )[0-9.]+ ms$/\10.000000 ms/" > "$work/$id.txt"
  # Every command must appear in the transcript, in order, exactly as it was shown.
  ECHO_ONLY=1 bash --norc --noprofile "$work/run.sh" "$c" > "$work/$id.want" 2>/dev/null || true
  perl -e 'local $/; open my $W, "<", $ARGV[0] or die; my @w = split /\0/, <$W>; open my $T, "<", $ARGV[1] or die; my $t = <$T>;
    my $at = 0; for my $x (@w) { my $i = index($t, $x, $at); if ($i < 0) { print "missing: $x"; exit 1 } $at = $i + length $x } exit(@w ? 0 : 1)' \
    "$work/$id.want" "$work/$id.txt" > "$work/$id.miss" || bad+=("term-$id(transcript: $(head -c 200 "$work/$id.miss"))")
  if grep -qE '^cargo test( |$)|[;&|]\s*cargo test( |$)' "$c"; then
    why=$(test_facts "$work/$id.txt") || bad+=("term-$id(test facts: $why)")
  fi
  jq -n --arg id "term-$id" --rawfile cmds "$c" --rawfile so "$work/$id.txt" \
    --argjson rc "$rc" --arg sha "$(sha256sum "$work/$id.txt" | cut -d' ' -f1)" \
    '{id:$id, command:$cmds, commands:($cmds|rtrimstr("\n")|split("\n")), exit:$rc, stdout:$so, stdout_sha256:$sha, plots:[]}' >> "$rows" || { echo "FAIL $id row jq" >&2; exit 1; }
  echo "term-$id $(wc -c < "$work/$id.txt") bytes exit=$rc"
  [ "$rc" -eq 0 ] || bad+=("term-$id(exit=$rc)")
  n=$((n + 1))
done
[ ${#bad[@]} -eq 0 ] || { echo "FAIL ${#bad[@]} term demo(s) refused: ${bad[*]}" >&2; exit 1; }
jq -s --arg commit "${GITHUB_SHA:-$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)}" --arg wf "${GITHUB_WORKFLOW:-local}" --arg run "${GITHUB_RUN_ID:-local}" \
  '{schema:"demo-json/v1",course:"ads-c01-rust",commit:$commit,workflow:$wf,run_id:$run,demos:.}' "$rows" >"$OUT.tmp" || { rm -f "${OUT:?}.tmp"; echo "FAIL final jq" >&2; exit 1; }
mv "$OUT.tmp" "$OUT"
echo "wrote $OUT ($n demos)"
