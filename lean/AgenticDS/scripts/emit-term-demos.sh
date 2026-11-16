#!/usr/bin/env bash
# emit-term-demos.sh <demo.json in> <demo.json out>: one term-<id> demo per term-demos/<id>.cmds, appended to .demos.
# Each file is typed into ONE bash session (cwd = repo root, env = term-demos/env only), one command at a time: lines
# are joined until `bash -n` parses them, so a quoted string that spans lines runs as one command, shown as an
# interactive shell shows it ("$ " first line, "> " continuation lines). stdout is the session transcript, ANSI stripped.
# Fails closed, and writes no <out>, when: there are no .cmds files; a file ends inside an unparsed command; a
# command is not found or not executable (126/127); a session exits non-zero or times out (124); a transcript does
# not show every command it was given. TERM_DEMO_ONLY="id id" runs just those ids.
# Nothing is staged or removed: every file a .cmds names is tracked, so a clean checkout shows what CI shows.
# A session that runs the full gate (make gate-lean, ~17 min on a runner) needs the 2400 s default, not 900.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)        # lean/AgenticDS
root=$(cd "$here/../.." && pwd)               # repo root (where the sessions start)
in=${1:?usage: emit-term-demos.sh <demo.json in> <demo.json out>}; out=${2:?usage: emit-term-demos.sh <in> <out>}
dir="$here/term-demos"
[ -d "$dir" ] || { echo "FAIL no $dir" >&2; exit 1; }
command -v script >/dev/null || { echo "FAIL util-linux script missing" >&2; exit 1; }
shopt -s nullglob
cmds=("$dir"/*.cmds)
[ -z "${TERM_DEMO_ONLY:-}" ] || { sel=(); for c in "${cmds[@]}"; do case " $TERM_DEMO_ONLY " in *" $(basename "$c" .cmds) "*) sel+=("$c");; esac; done; cmds=("${sel[@]}"); }
[ ${#cmds[@]} -gt 0 ] || { echo "FAIL no $dir/*.cmds" >&2; exit 1; }
work=$(mktemp -d "${RUNNER_TEMP:-$here/.lake}/term-demos.XXXXXX")
[ -n "${TERM_DEMO_KEEP:-}" ] || trap 'rm -rf "${work:?}"' EXIT
mapfile -t envv < <(grep -vE '^\s*(#|$)' "$dir/env")
strip() { perl -pe 's/\e\][^\a\e]*(\a|\e\\)//g; s/\e\[[0-?]*[ -\/]*[@-~]//g; s/\e[()][A-Z0-9]//g; s/\e[=>]//g; s/\r//g'; }
cat > "$work/run.sh" <<'RUN'
stty cols 93 rows 25 2>/dev/null
PS1='$ '
__b=""; __p=0   # __p = status of the previous command, restored before each eval so `echo "exit=$?"` reports it, not the status of the display pipeline
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
# Warm the toolchain with the sessions own env BEFORE any recorded command: a cold elan home prints download/install
# lines into the first session that runs lake, which a warm recording never shows. Output is not recorded.
mkdir -p /tmp/rts-home-lean
( cd "$here" && env -i "${envv[@]}" lake --version ) >/dev/null 2>&1 </dev/null || { echo "FAIL toolchain warm-up (lake --version) failed" >&2; exit 1; }
rows="$work/rows.jsonl"; : > "$rows"; bad=()
for c in "${cmds[@]}"; do
  id=$(basename "$c" .cmds)
  mkdir -p /tmp/rts-home-lean
  ( cd "$root" && env -i "${envv[@]}" timeout "${TERM_DEMO_TIMEOUT_S:-2400}" script -qefc "bash --norc --noprofile $work/run.sh $c" /dev/null ) \
    > "$work/$id.raw" 2>&1 </dev/null && rc=0 || rc=$?
  strip < "$work/$id.raw" > "$work/$id.txt"
  # Every command must appear in the transcript, in order, exactly as it was shown (the same joiner, echo only).
  ECHO_ONLY=1 bash --norc --noprofile "$work/run.sh" "$c" > "$work/$id.want" 2>/dev/null || true
  perl -e 'local $/; open my $W, "<", $ARGV[0] or die; my @w = split /\0/, <$W>; open my $T, "<", $ARGV[1] or die; my $t = <$T>;
    my $at = 0; for my $x (@w) { my $i = index($t, $x, $at); if ($i < 0) { print "missing: $x"; exit 1 } $at = $i + length $x } exit(@w ? 0 : 1)' \
    "$work/$id.want" "$work/$id.txt" > "$work/$id.miss" || { bad+=("term-$id(transcript: $(head -c 200 "$work/$id.miss"))"); }
  jq -n --arg id "term-$id" --rawfile cmds "$c" --rawfile so "$work/$id.txt" \
    --argjson rc "$rc" --arg sha "$(sha256sum "$work/$id.txt" | cut -d' ' -f1)" \
    '{id:$id, command:$cmds, commands:($cmds|rtrimstr("\n")|split("\n")), exit:$rc, stdout:$so, stdout_sha256:$sha, plots:[]}' >> "$rows"
  echo "term-$id $(wc -c < "$work/$id.txt") bytes exit=$rc"
  [ "$rc" -eq 0 ] || bad+=("term-$id(exit=$rc)")
done
[ ${#bad[@]} -eq 0 ] || { echo "FAIL ${#bad[@]} term demo(s) did not exit 0: ${bad[*]}" >&2; exit 1; }
jq --slurpfile r "$rows" '.demos += $r' "$in" > "$out"
