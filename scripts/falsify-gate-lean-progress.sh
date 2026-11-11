#!/usr/bin/env bash
# The heartbeat switch is for demos; this falsifier always tests the default (2 s).
unset GATE_LEAN_HEARTBEAT_S
# Planted arms for the progress output of scripts/gate-lean.sh (ads c05 m1-09): the gate must print a stage line at once and
# an elapsed line every 2 s while a stage runs, so a recording never shows a blank terminal. A gate without stage lines is refused.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT; pass=0; fail=0
mkdir -p "$t/scripts" "$t/lean/AgenticDS" "$t/home/.elan/bin"
printf '#!/bin/sh\nsleep 5\nexit 1\n' > "$t/home/.elan/bin/lake"; chmod +x "$t/home/.elan/bin/lake"
run() { # gate-file -> out file with "elapsed-seconds line" rows and the exit code in $t/rc
  cp "$1" "$t/scripts/gate-lean.sh"; chmod +x "$t/scripts/gate-lean.sh"
  : > "$t/out"; s=$(date +%s.%N)
  HOME="$t/home" "$t/scripts/gate-lean.sh" 2>&1 | while IFS= read -r l; do printf '%s %s\n' "$(echo "$(date +%s.%N) - $s" | bc -l)" "$l"; done > "$t/out"
  echo "${PIPESTATUS[0]}" > "$t/rc"; }
check() { # name expect(pass|refuse) gate-file
  run "$3"; first=$(awk 'NR==1{print $1}' "$t/out"); hb=$(grep -c '\.\.\. [0-9]* s$' "$t/out")
  ok=1
  [ -n "$first" ] && [ "$(echo "$first < 2.0" | bc -l)" = 1 ] || ok=0     # first line within 2 s
  grep -q '\[1/[0-9]*\] lake build' "$t/out" || ok=0                      # names the first stage
  [ "$hb" -ge 1 ] || ok=0                                                 # an elapsed line during the silent 5 s stage
  grep -q 'FAIL lean build' "$t/out" || ok=0                              # the real failure message still prints
  if { [ "$2" = pass ] && [ "$ok" = 1 ]; } || { [ "$2" = refuse ] && [ "$ok" = 0 ]; }; then
    echo "  $1 ok"; pass=$((pass+1)); else echo "  $1 FAIL (first=$first hb=$hb)"; fail=$((fail+1)); fi; }
check 00-control pass scripts/gate-lean.sh
grep -v -e '^stage "' -e '^stage()' scripts/gate-lean.sh > "$t/nostage.sh"; check 01-no-stage-lines refuse "$t/nostage.sh"
sed 's/sleep 2 >\/dev\/null 2>&1; do/sleep 99 >\/dev\/null 2>&1; do/' scripts/gate-lean.sh > "$t/nohb.sh"; check 02-no-heartbeat refuse "$t/nohb.sh"
n=$(grep -c '^stage "' scripts/gate-lean.sh); want=$(sed -n 's/^NSTAGES=\([0-9]*\);.*/\1/p' scripts/gate-lean.sh)
if [ "$n" = "$want" ]; then echo "  03-stage-count ok ($n)"; pass=$((pass+1)); else echo "  03-stage-count FAIL ($n stage lines, NSTAGES=$want)"; fail=$((fail+1)); fi
echo "falsify-gate-lean-progress: $pass pass, $fail fail"; [ "$fail" -eq 0 ]
