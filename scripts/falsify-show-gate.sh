#!/usr/bin/env bash
# Falsifier for scripts/show-gate.sh: clean run shows both headers, the exact source lines and the gate verdict;
# an unknown gate, a range outside the file, and a failing gate are each refused.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
f=ontology/shapes/example.shape.ttl
out=$(scripts/show-gate.sh shacl </dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL clean run: rc=$rc"; exit 1; }
[ "$(printf '%s\n' "$out" | sed -n 1p)" = "== source: $f 1-23 ==" ] || { echo "FAIL source header"; exit 1; }
[ "$(printf '%s\n' "$out" | sed -n 2,24p)" = "$(sed -n 1,23p "$f")" ] || { echo "FAIL source lines differ from $f"; exit 1; }
[ "$(printf '%s\n' "$out" | sed -n 25p)" = "== run: make gate-shacl ==" ] || { echo "FAIL run header"; exit 1; }
printf '%s\n' "$out" | tail -n 1 | grep -q 'shacl OK' || { echo "FAIL last line lacks shacl OK"; exit 1; }
scripts/show-gate.sh nope >/dev/null 2>&1; [ $? -eq 2 ] || { echo "FAIL unknown gate not refused with 2"; exit 1; }
scripts/show-gate.sh >/dev/null 2>&1; [ $? -eq 2 ] || { echo "FAIL empty gate not refused with 2"; exit 1; }
t=$(mktemp -d); trap 'rm -rf "${t:?}"' EXIT
SHOW_GATE_ROWS="shacl|$f|1|9999|gate-shacl" scripts/show-gate.sh shacl </dev/null >/dev/null 2>&1; [ $? -eq 2 ] || { echo "FAIL range outside file not refused with 2"; exit 1; }
SHOW_GATE_ROWS="shacl|nofile.ttl|1|2|gate-shacl" scripts/show-gate.sh shacl </dev/null >/dev/null 2>&1; [ $? -eq 2 ] || { echo "FAIL missing file not refused with 2"; exit 1; }
printf '#!/bin/sh\necho planted gate failure\nexit 7\n' >"$t/make"; chmod +x "$t/make"
MAKE="$t/make" scripts/show-gate.sh shacl </dev/null >/dev/null 2>&1; [ $? -eq 7 ] || { echo "FAIL failing gate did not fail the script"; exit 1; }
out=$(MAKE="$t/make" scripts/show-gate.sh shacl </dev/null 2>&1); [ $? -eq 7 ] && [ "$(printf '%s\n' "$out" | tail -n 1)" = "planted gate failure" ] || { echo "FAIL failing gate: output not printed with its status"; exit 1; }
printf "#!/bin/sh\necho fake gate ran\n" >"$t/ok"; chmod +x "$t/ok"
mkfifo "$t/in" "$t/out"
MAKE="$t/ok" scripts/show-gate.sh shacl <"$t/in" >"$t/out" 2>&1 &
exec 3>"$t/in" 4<"$t/out"
for i in $(seq 24); do read -r -u 4 _ || { echo "FAIL pause: short source stage"; exit 1; }; done
if read -r -t 1 -u 4 l; then echo "FAIL pause: output past the source stage before Enter: $l"; exit 1; fi
echo >&3
read -r -u 4 l1; read -r -u 4 l2
[ "$l1" = "== run: make gate-shacl ==" ] && [ "$l2" = "fake gate ran" ] || { echo "FAIL pause: after Enter got: $l1 | $l2"; exit 1; }
exec 3>&-; wait $!; [ $? -eq 0 ] || { echo "FAIL pause: script status"; exit 1; }
printf "#!/bin/sh\necho fake gate ran\n" >"$t/ok"
out=$(printf "run\n" | MAKE="$t/ok" scripts/show-gate.sh shacl 2>&1); [ "$(printf "%s\n" "$out" | tail -n 2)" = "== run: make gate-shacl ==
fake gate ran" ] || { echo "FAIL a typed run line did not release the pause"; exit 1; }
# rust row: the source stage is the first 13 lines of the gate script; the run stage is a planted make (the real gate is not run here).
printf '#!/bin/sh\necho "planted $*"\n' >"$t/ok"
out=$(MAKE="$t/ok" scripts/show-gate.sh rust </dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | sed -n 1p)" = "== source: scripts/gate-rust.sh 1-13 ==" ] && [ "$(printf '%s\n' "$out" | sed -n 2,14p)" = "$(sed -n 1,13p scripts/gate-rust.sh)" ] || { echo "FAIL rust row: source stage"; exit 1; }
[ "$(printf '%s\n' "$out" | tail -n 2)" = "== run: make gate-rust ==
planted --no-print-directory gate-rust" ] || { echo "FAIL rust row: run stage does not call make gate-rust"; exit 1; }
echo "show-gate falsifier OK"
