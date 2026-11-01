#!/usr/bin/env bash
# Falsifier for rerun-lean-demos.sh (ads#132): the check must refuse each planted fault and pass the good demo.
# Arms: A empty stdout (exit 0), B exit 1, C stdout differs per run, D contract-listed demo with no contract line,
# E good demo with a contract line. A-D must fail, E must pass. Run from lean/AgenticDS.
set -uo pipefail
S=$(mktemp -d); trap 'rm -rf "${S:?}"' EXIT
mkdir -p "$S/bin"
stub() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$S/bin/example-m$1"; chmod +x "$S/bin/example-m$1"; }
fail=0
run() { # arm want(0|1) body ids
  stub 9 "$3"
  scripts/rerun-lean-demos.sh 3 "$S/bin" "$4" >"$S/o" 2>&1; rc=$?
  if { [ "$2" = 1 ] && [ "$rc" -ne 0 ]; } || { [ "$2" = 0 ] && [ "$rc" -eq 0 ]; }; then echo "arm $1 ok ($(cat "$S/o"))"; else echo "FAIL arm $1: rc=$rc $(cat "$S/o")"; fail=1; fi
}
run A-empty-stdout 1 'exit 0' m9v01
run B-exit-1 1 'echo hi; exit 1' m9v01
run C-differs 1 'echo $RANDOM$RANDOM$$' m9v01
run E-good 0 'echo "contract: x OK"' m9v01
# Arm D needs a demo on the contract list: a temp list names m9v02.
echo m9v02 > "$S/list"
CONTRACT_LIST="$S/list" run D-listed-no-contract-line 1 'echo "hello"' m9v02
[ "$fail" -eq 0 ] && echo "falsifier OK (5 arms)"
exit "$fail"
