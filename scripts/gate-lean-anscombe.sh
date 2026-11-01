#!/usr/bin/env bash
# Lean Anscombe lesson gate (ADS-DEMO-001): warnings-as-errors build, no sorry/SATD, the test, the exe's contract line,
# and the committed stdout parity with the shared data.
set -uo pipefail
cd "$(dirname "$0")/../lean/anscombe" || exit 1
export PATH="$HOME/.elan/bin:$PATH" ADS_ROOT=../..
lake build >/dev/null 2>&1 || { echo "FAIL anscombe build"; lake build 2>&1 | tail -20; exit 1; }
if grep -rn --include=*.lean -E "\b(sorry|admit)\b|native_decide|TODO|FIXME|HACK|XXX" Anscombe.lean Anscombe Main.lean Test.lean; then echo "FAIL sorry/admit/native_decide/SATD"; exit 1; fi
out=$(lake exe anscombe-test 2>&1) || { echo "FAIL anscombe test: $out"; exit 1; }
echo "$out" | grep -q "contract: ads-lean-anscombe-test-v1 OK$" || { echo "FAIL anscombe test: $out"; exit 1; }
out=$(lake exe anscombe 2>&1) || { echo "FAIL anscombe exe: $out"; exit 1; }
echo "$out" | tail -n 1 | grep -q "contract: ads-lean-anscombe-v1 four sets, one summary OK$" || { echo "FAIL anscombe exe: $out"; exit 1; }
# Can fail: a reordered data file must change the report (the sets are read by name, so the report is order-free; an edited value is not).
t=$(mktemp -d); trap 'rm -rf "${t:?}"' EXIT
mkdir -p "$t/data/anscombe"; sed 's/^IV,8,6.58$/IV,8,7.58/' ../../data/anscombe/anscombe.csv > "$t/data/anscombe/anscombe.csv"
cmp -s "$t/data/anscombe/anscombe.csv" ../../data/anscombe/anscombe.csv && { echo "FAIL planted edit did not change the data"; exit 1; }
if ADS_ROOT="$t" lake exe anscombe >/dev/null 2>&1; then echo "FAIL a changed data value stayed green"; exit 1; fi
echo "lean anscombe OK"
