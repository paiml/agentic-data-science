#!/usr/bin/env bash
# Staged gate demo: print the source lines a lesson describes, then run the live gate.
# usage: scripts/show-gate.sh <gate>   (exit 2 on a bad gate, file or range; else the gate's own status)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
# table row: gate|file|first|last|make target
rows="${SHOW_GATE_ROWS:-shacl|ontology/shapes/example.shape.ttl|1|23|gate-shacl
rust|scripts/gate-rust.sh|1|13|gate-rust}"
gate="${1:-}"
row=$(printf '%s\n' "$rows" | grep -m1 "^${gate}|") && [ -n "$gate" ] || { echo "show-gate: unknown gate '$gate'" >&2; exit 2; }
IFS='|' read -r _ file first last target <<<"$row"
[ -f "$file" ] || { echo "show-gate: missing file $file" >&2; exit 2; }
total=$(wc -l <"$file")
{ [ "$first" -ge 1 ] && [ "$first" -le "$last" ] && [ "$last" -le "$total" ]; } || { echo "show-gate: range $first-$last outside $file ($total lines)" >&2; exit 2; }
echo "== source: $file $first-$last =="
sed -n "${first},${last}p" "$file"
read -r _ || true  # pause: the run stage starts on Enter (EOF continues)
echo "== run: make $target =="
# The demo shows the gate's full real output, printed in one piece once the gate has finished.
# The log is removed BEFORE the output is printed, so the script exits right after its last line:
# a terminal that closes on the verdict line does not catch the script still cleaning up.
log=$(mktemp) || exit 2
trap 'rm -f "${log:?}"' EXIT
"${MAKE:-make}" --no-print-directory "$target" >"$log" 2>&1
rc=$?
out=$(cat "$log")
rm -f "${log:?}"
trap - EXIT
[ -z "$out" ] || printf '%s\n' "$out"
exit "$rc"
