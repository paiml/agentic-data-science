#!/usr/bin/env bash
# readme-run.sh [README] [RECEIPT.tsv] : D46 item 3. Runs EVERY ```bash block of the lab README verbatim, in order,
# from the lab directory. A block's first line may be `# expect: N` (default 0): the exit code it must return.
# Receipt: one TSV row per step: n<TAB>expect<TAB>exit<TAB>seconds<TAB>PASS|FAIL. Exit 0 = every step as expected,
# 1 = a step differed, 2 = not measured (no README, or zero blocks: a zero-step lab never passes).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); lab=$(cd "$here/.." && pwd)
R=${1:-$lab/README.md}; OUT=${2:-/dev/stdout}
[ -s "$R" ] || { echo "NOT MEASURED: $R missing" >&2; exit 2; }
T=$(mktemp -d); trap 'rm -rf "${T:?}"' EXIT
awk -v d="$T" '/^```bash[[:space:]]*$/{n++;on=1;next} /^```/{on=0;next} on{print > (d "/" sprintf("%03d",n) ".sh")}' "$R"
steps=$(find "$T" -name '*.sh' | sort)
[ -n "$steps" ] || { echo "NOT MEASURED: no bash blocks in $R" >&2; exit 2; }
bad=0; i=0; : > "$T/receipt"
for s in $steps; do
  i=$((i+1)); want=$(sed -n '1s/^# expect: *\([0-9][0-9]*\) *$/\1/p' "$s"); want=${want:-0}
  t0=$(date +%s.%N); ( cd "$lab" && bash "$s" </dev/null >"$T/out.$i" 2>&1 ); got=$?; t1=$(date +%s.%N)
  v=PASS; [ "$got" -eq "$want" ] || { v=FAIL; bad=$((bad+1)); tail -n 5 "$T/out.$i" >&2; }
  printf '%s\t%s\t%s\t%.1f\t%s\n' "$i" "$want" "$got" "$(echo "$t1 - $t0" | bc)" "$v" >> "$T/receipt"
done
cat "$T/receipt" > "$OUT"
[ "$bad" -eq 0 ] || exit 1
