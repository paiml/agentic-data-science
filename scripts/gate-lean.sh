#!/usr/bin/env bash
# Lean gate in four stages, each printing the tool's own output:
#   1 build (warnings are errors), 2 scan (make lean-scan: no sorry/native_decide/SATD markers),
#   3 axioms (within the allowed set), 4 golden parity (tests) + scene specs replayed.
# pmat reads no Lean sources (measured 10-22, pmat 3.42.0: planted TODO file stays green), so it is not a Lean gate.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/lean/AgenticDS" || exit 1
export PATH="$HOME/.elan/bin:$PATH"
# Same linters as lakefile.toml leanOptions, for the test files lake does not build.
LEANOPTS=(-DwarningAsError=true -Dweak.linter.mathlibStandardSet=true -Dweak.linter.style.longLine.maxLineLength=68 "-Dweak.linter.style.header.license=Released under MIT license as described in the file LICENSE.")
okax='depends on axioms: \[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]$'

# show CMD...: run it, print its own output whole, return its status.
show() {
  local out rc
  out=$("$@" 2>&1); rc=$?
  printf '%s\n' "$out"
  LAST="$out"
  return "$rc"
}

lake build || { echo "FAIL lean build"; exit 1; }
echo "stage 1/4 build OK"

make --no-print-directory -C "$root" lean-scan || { echo "FAIL scan"; exit 1; }
echo "stage 2/4 scan OK"

for f in scripts/Axioms.lean scripts/AxiomsM*.lean; do
  [ -e "$f" ] || continue
  want=$(grep -c '^#print axioms' "$f")
  [ "$want" -ge 1 ] || { echo "FAIL $f lists no theorem"; exit 1; }
  show lake env lean -DwarningAsError=true "$f" || { echo "FAIL $f did not elaborate"; exit 1; }
  [ "$(printf '%s\n' "$LAST" | grep -c 'depends on axioms')" = "$want" ] || { echo "FAIL $f: expected $want theorem lines"; exit 1; }
  bad=$(printf '%s\n' "$LAST" | grep "depends on axioms" | grep -vE "$okax")
  [ -z "$bad" ] || { echo "FAIL $f: $bad"; exit 1; }
done
echo "stage 3/4 axioms OK"

# test FILE VERDICT: run a test file natively; its output must end in the contract verdict.
test_file() {
  show lake env lean "${LEANOPTS[@]}" --run "$1" ../.. || { echo "FAIL $1"; exit 1; }
  printf '%s\n' "$LAST" | grep -q "$2$" || { echo "FAIL $1: no '$2'"; exit 1; }
}
test_file AgenticDSTest/Main.lean "contract: ads-lean-p1-v1 OK"
test_file AgenticDSTest/OlsTest.lean "contract: ads-lean-p2-v1 OK"
printf '%s\n' "$LAST" | grep -qxE "[1-9][0-9]* checks passed" || { echo "FAIL ols test: no checks-passed line"; exit 1; }
[ ! -e AgenticDSTest/P4.lean ] || test_file AgenticDSTest/P4.lean "contract: ads-lean-p4-v1 OK"
for n in 1 2 3 4; do
  if grep -q '^def scenesM'"$n"' .*:= \[\]$' "AgenticDS/Scenes/M$n.lean"; then
    # A module whose table is empty lands in its own PR: the test must say so and print no contract line.
    test_file "AgenticDSTest/ScenesM$n.lean" "scenes-m$n: none yet (lands in its own PR)"
    ! printf '%s\n' "$LAST" | grep -q "^contract:" || { echo "FAIL ScenesM$n: contract line on an empty module"; exit 1; }
  else
    test_file "AgenticDSTest/ScenesM$n.lean" "contract: ads-lean-scenes-m$n-v1 OK"
  fi
done
show "$root/scripts/scene-spec.sh" selftest || exit 1
for spec in "$root"/demos/e-m*/scenes.spec; do
  [ -e "$spec" ] || continue
  show "$root/scripts/scene-spec.sh" replay "$spec" || { echo "FAIL scene spec $spec"; exit 1; }
done
echo "stage 4/4 golden parity OK"
echo "lean OK"
