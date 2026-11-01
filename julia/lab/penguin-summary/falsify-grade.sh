#!/usr/bin/env bash
# Falsifier for grade.sh, on REAL Julia (JULIA, else julia on PATH, else julia-docker.sh = the pinned sandbox image).
# Arms (grade.sh as shipped must give the stated result):
#   A solution PASS                          B starter (red suite) FAIL
#   C starter + planted __init__ that prints the pass line and calls exit(0)      -> FAIL (forged output)
#   D solution + planted __init__ that calls exit(0) before any test              -> FAIL (no result file)
#   E learner's test/runtests.jl emptied -> FAIL   F learner's test/runtests.jl deleted, solution code -> PASS (grader copy is used)
#   G grader copy missing -> REFUSED rc 2    H suite with zero checks -> FAIL
#   I solution + atexit(exit(3)): clean result file, non-zero exit -> FAIL (exit-code check)
#   J grader runner that always exits 0, starter code, MIN_TOTAL=0: fail/error counts in the result -> FAIL
# Mutants: each defence line of grade.sh is removed in a scratch copy, and the arm that depends on it must flip.
# An arm that cannot flip proves nothing.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
if [ -z "${JULIA:-}" ]; then if command -v julia >/dev/null; then JULIA=julia; else JULIA=$here/julia-docker.sh; fi; fi
export JULIA
S=$(mktemp -d); trap 'rm -rf "${S:?}"' EXIT
chmod 755 "$S"
fail=0
mk() { # name source-tree: a learner tree
  rm -rf "${S:?}/${1:?}"; mkdir -p "$S/$1"; cp -R "$here/$2/." "$S/$1/"
}
plant() { # tree line: add a line before the module's final end
  local f="$S/$1/src/AgenticDS.jl" n
  n=$(grep -n '^end' "$f" | tail -n 1 | cut -d: -f1)
  sed -i "${n}i\\
$2" "$f"
}
grade() { # script learner [env...] -> prints rc
  local script=$1 learner=$2; shift 2
  env GRADER_DIR="$here" "$@" bash "$script" "$S/$learner" >"$S/last.out" 2>&1; echo $?
}
check() { # name rc want(0|nz|2)
  local ok=0
  case "$3" in 0) [ "$2" -eq 0 ] && ok=1;; nz) [ "$2" -ne 0 ] && ok=1;; 2) [ "$2" -eq 2 ] && ok=1;; esac
  if [ "$ok" = 1 ]; then echo "arm $1 ok (rc=$2: $(tail -n 1 "$S/last.out"))"; else echo "FAIL arm $1: rc=$2 want $3: $(tail -n 2 "$S/last.out")"; fail=1; fi
}
mk sol solution; mk sta starter
mk forged starter
plant forged '__init__() = (println("Lab: penguin summary |   73     73  1.0s"); println("GRADE: PASS"); exit(0))'
mk early solution; plant early '__init__() = exit(0)'
mk emptied solution; : > "$S/emptied/test/runtests.jl"
mk deleted solution; rm -f "${S:?}/deleted/test/runtests.jl"
mk exit3 solution; plant exit3 '__init__() = atexit(() -> exit(3))'
mk zero solution; rm -f "${S:?}/zero/test/runtests.jl"
# grader dirs: an empty suite, a runner that always exits 0, and an empty one
mkdir -p "$S/g-zero/solution/test" "$S/g-exit0/solution/test" "$S/g-none"
cp "$here/run.jl" "$S/g-zero/run.jl"; printf 'using Test\n@testset "none" begin end\n' > "$S/g-zero/solution/test/runtests.jl"
sed 's/^exit(f + e == 0 ? 0 : 1)$/exit(0)/' "$here/run.jl" > "$S/g-exit0/run.jl"
cp "$here/solution/test/runtests.jl" "$S/g-exit0/solution/test/"
cmp -s "$S/g-exit0/run.jl" "$here/run.jl" && { echo "FAIL: the exit-0 runner fixture equals the real runner (run.jl changed)"; exit 1; }

echo "== shipped grade.sh"
check A "$(grade "$here/grade.sh" sol)" 0
check B "$(grade "$here/grade.sh" sta)" nz
check C "$(grade "$here/grade.sh" forged)" nz
check D "$(grade "$here/grade.sh" early)" nz
check E "$(grade "$here/grade.sh" emptied)" nz
check F "$(grade "$here/grade.sh" deleted)" 0
check G "$(grade "$here/grade.sh" sol GRADER_DIR="$S/g-none")" 2
check H "$(grade "$here/grade.sh" zero GRADER_DIR="$S/g-zero")" nz
check I "$(grade "$here/grade.sh" exit3)" nz
check J "$(grade "$here/grade.sh" sta GRADER_DIR="$S/g-exit0" MIN_TOTAL=0)" nz
grep -q "(0 failed, 9 errored)" "$S/last.out" || { echo "FAIL arm J: counts were not read from the result file: $(tail -n 1 "$S/last.out")"; fail=1; }

echo "== mutants (the dependent arm must flip)"
mutant() { # name sed-expr learner flipped-rc(0|nz) [env...]
  local name=$1 expr=$2 learner=$3 flipped=$4 rc; shift 4
  sed "$expr" "$here/grade.sh" > "$S/m.sh"
  if cmp -s "$S/m.sh" "$here/grade.sh"; then echo "FAIL mutant $name: sed changed nothing (the line moved)"; fail=1; return; fi
  rc=$(grade "$S/m.sh" "$learner" "$@")
  if { [ "$flipped" = 0 ] && [ "$rc" -eq 0 ]; } || { [ "$flipped" = nz ] && [ "$rc" -ne 0 ]; }; then
    echo "mutant $name flips its arm (rc=$rc): the arm is sensitive"
  else echo "FAIL mutant $name: arm did not flip (rc=$rc)"; fail=1; fi
}
mutant no-copy-in       '/^mkdir -p "\$work\/test"; cp "\$tests"/d' deleted nz
mutant no-exit-check    '/^if \[ "\$rc" -ne 0 \]; then echo "GRADE: FAIL (exit/d' exit3 0
mutant no-failerr-check '/^if \[ "\$fail" -ne 0 \] || \[ "\$error" -ne 0 \]/d' sta 0 GRADER_DIR="$S/g-exit0" MIN_TOTAL=0
mutant no-min-total     '/^if \[ "\$pass" -lt "\$MIN_TOTAL" \]/d' zero 0 GRADER_DIR="$S/g-zero"
mutant no-result-gate   '/^\[ -f "\$result" \] || /d;/^\[ "\$got_nonce" = /d;/^case "\$pass\$fail\$error" in/d;s|^read -r got_nonce pass fail error < "\$result"|got_nonce=x; pass=; fail=; error=|' early 0
[ "$fail" -eq 0 ] && echo "falsifier OK (10 arms, 5 mutants, real Julia)"
exit "$fail"
