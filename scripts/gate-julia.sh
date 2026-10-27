#!/usr/bin/env bash
# Julia gate: Pkg.test (incl. Aqua + JET) with coverage, Coverage.jl lines must be 100, JuliaFormatter no diff.
# Other Julia packages under julia/ get Pkg.test (incl. JET) and the format check.
# Usage: gate-julia.sh [part ...]. Parts: AgenticDS (the main package) and each other package directory name.
# No argument runs every part. CI runs one part per matrix job and sets ADS_JULIA_PARTS to the full matrix
# list; every package directory must be in that list, so a new package cannot be left out of CI.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)" || exit 1
depot="${ADS_JULIA_DEPOT:-}"
if [ -n "$depot" ]; then export JULIA_DEPOT_PATH="$depot"; fi
pkg="$root/julia/AgenticDS.jl"
gate="$root/julia/gate"
cd "$root" || exit 1

others=()
for p in "$root"/julia/*/; do
  p="${p%/}"
  [ -f "$p/Project.toml" ] || continue
  case "$p" in "$pkg" | "$gate") continue ;; esac
  others+=("${p##*/}")
done

if [ -n "${ADS_JULIA_PARTS:-}" ]; then
  for n in AgenticDS "${others[@]}"; do
    case " $ADS_JULIA_PARTS " in *" $n "*) ;; *) echo "FAIL julia part $n is not in the CI matrix"; exit 1 ;; esac
  done
fi

parts=("$@")
if [ ${#parts[@]} -eq 0 ]; then parts=(AgenticDS "${others[@]}"); fi

main_part() {
  find "$pkg" -name '*.cov' -delete
  julia --project="$gate" -e 'using Pkg; Pkg.instantiate()'
  julia --project="$pkg" -e 'using Pkg; Pkg.instantiate()'
  julia --project="$pkg" --inline=no -e 'using Pkg; Pkg.test(coverage = true)'
  julia --project="$gate" "$root/scripts/julia-coverage.jl" "$pkg"
  julia --project="$gate" "$root/scripts/julia-format.jl" "$pkg"
  find "$pkg" -name '*.cov' -delete
  for e in "$pkg"/examples/*/run.jl; do julia --project="$pkg" "$e" > /dev/null; done
  echo "examples OK"
}

other_part() {
  local p="$root/julia/$1"
  [ -f "$p/Project.toml" ] || { echo "FAIL no julia package $1"; exit 1; }
  julia --project="$p" -e 'using Pkg; Pkg.instantiate()'
  julia --project="$p" --inline=no -e 'using Pkg; Pkg.test()'
  scripts/julia-format.sh "$p"
}

for part in "${parts[@]}"; do
  if [ "$part" = AgenticDS ]; then main_part; else other_part "$part"; fi
done
echo "gate-julia OK"
