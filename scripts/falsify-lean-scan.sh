#!/usr/bin/env bash
# Falsifier for scripts/lean-scan.sh: (1) its grep line equals gate-lean.sh's marker grep; (2) clean tree -> exit 0;
# (3) a planted native_decide file -> exit 2 naming the file; (4) the planted file is removed afterwards.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
pat() { grep -o 'grep -rn --include=\*\.lean --include=\*\.lean\.planted -E "[^"]*" AgenticDS\.lean AgenticDS AgenticDSTest scripts' "$1"; }
a=$(pat scripts/gate-lean.sh); b=$(pat scripts/lean-scan.sh)
[ -n "$a" ] && [ "$a" = "$b" ] || { echo "FAIL lean-scan pattern drifted from gate-lean.sh"; exit 1; }
out=$(scripts/lean-scan.sh 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "scan: no markers" ] || { echo "FAIL clean tree: rc=$rc $out"; exit 1; }
p=lean/AgenticDS/AgenticDS/FalsifyLeanScan.lean
[ ! -e "$p" ] || { echo "FAIL $p already exists"; exit 1; }
trap 'rm -f "$p"' EXIT
printf 'theorem planted : 2 + 2 = 4 := by native_decide\n' > "$p"
out=$(scripts/lean-scan.sh 2>&1); rc=$?
rm -f "$p"
[ "$rc" -eq 2 ] || { echo "FAIL planted marker: rc=$rc (want 2)"; exit 1; }
echo "$out" | grep -q "FalsifyLeanScan.lean:1:" || { echo "FAIL planted marker not named: $out"; exit 1; }
[ ! -e "$p" ] || { echo "FAIL planted file left behind"; exit 1; }
echo "lean-scan falsifier OK"
