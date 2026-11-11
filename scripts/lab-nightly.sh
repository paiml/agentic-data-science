#!/usr/bin/env bash
# LAB lane (agentic-data-science#143): every lab's falsifier on its REAL toolchain. Never a gate, never on a PR path.
# Per lab: solution PASSes, starter FAILs, every mutant / forge arm FAILs (the labs' own run-lab-proof.sh and falsify-grade.sh).
# A lane is GREEN only if its proof printed its floor lines (PROOF OK, the mutant lines, the arm count): an empty log is never green.
# Exit 0 all green | 1 any red | 2 nothing red but a lane could not be measured (toolchain absent: NOT RUN, never green).
# Env: LAB_ROOT (repo root, default this checkout), LAB_OUT (log dir), JULIA (julia binary, else julia on PATH), LAB_ONLY (space list of rust r julia).
set -uo pipefail
root=${LAB_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
out=${LAB_OUT:-$(mktemp -d)}; mkdir -p "$out"
only=${LAB_ONLY:-rust r julia c-m1}
: > "$out/summary.txt"
red=0; unmeasured=0
note() { printf '%s|%s|%s\n' "$1" "$2" "$3" | { read -r l; echo "$l" >> "$out/summary.txt"; echo "$l"; }; }
# run NAME TOOLCHECK-CMD NEEDLE... -- CMD... : green iff CMD exits 0 and every NEEDLE (grep -E) is in its log.
lane() {
  local name=$1 tool=$2; shift 2
  local needles=()
  while [ "$1" != "--" ]; do needles+=("$1"); shift; done; shift
  if ! command -v "$tool" >/dev/null 2>&1; then note "$name" "NOT RUN" "$tool not found"; unmeasured=1; return; fi
  local log=$out/$name.log
  "$@" </dev/null >"$log" 2>&1; local rc=$?
  if [ "$rc" -ne 0 ]; then note "$name" "RED" "exit $rc: $(tail -n 1 "$log" | cut -c1-120)"; red=1; return; fi
  local n
  for n in "${needles[@]}"; do
    grep -Eq -- "$n" "$log" || { note "$name" "RED" "exit 0 but the floor line is missing: $n"; red=1; return; }
  done
  note "$name" "GREEN" "$(grep -E 'PROOF OK|falsifier OK' "$log" | tr '\n' ' ' | cut -c1-120)"
}
has() { case " $only " in *" $1 "*) return 0;; esac; return 1; }
if has rust; then
  lane rust cargo 'PROOF OK' 'mutant popsd exit=[1-9]' 'mutant dropnull exit=[1-9]' -- \
    env MUTANTS=1 bash "$root/rust/lab/penguin-summary/run-lab-proof.sh"
fi
if has r; then
  if command -v Rscript >/dev/null && ! Rscript -e 'for (p in c("testthat","dplyr","readr","jsonlite","tibble")) library(p, character.only = TRUE)' >/dev/null 2>&1; then
    note r "NOT RUN" "R packages testthat dplyr readr jsonlite tibble not loadable"; unmeasured=1
  else
  lane r Rscript 'PROOF OK' 'mutant popsd exit=[1-9]' 'mutant dropsex exit=[1-9]' -- \
    env MUTANTS=1 bash "$root/r/lab/penguin-summary/run-lab-proof.sh"
  fi
fi
if has julia; then
  jl=${JULIA:-julia}
  # A fresh user-space julia has an empty depot: grade.sh defaults to JULIA_PKG_OFFLINE=true (sandbox image) and cannot instantiate, so the lane lets pkg fetch (ads#159).
  j=$root/julia/lab/penguin-summary
  lane julia "$jl" 'PROOF OK' 'falsifier OK \(14 arms, 5 mutants' -- \
    env JULIA_PKG_OFFLINE="${JULIA_PKG_OFFLINE:-false}" bash -c 'cd "$1" && JULIA="$2" bash run-lab-proof.sh && JULIA="$2" bash falsify-grade.sh' _ "$j" "$jl"
fi
if has c-m1; then
  if [ -f "$root/demos/c-m1/v01-ticket/oracle.R" ]; then
    lane c-m1 Rscript "F2 OK" -- bash "$root/scripts/falsify-c-m1-oracles.sh"
  else note c-m1 "NOT RUN" "demos/c-m1 oracles not on this ref (ads#78 unmerged)"; unmeasured=1; fi
fi
[ "$red" -eq 1 ] && exit 1
[ "$unmeasured" -eq 1 ] && exit 2
exit 0
