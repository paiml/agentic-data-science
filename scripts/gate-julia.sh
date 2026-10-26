#!/usr/bin/env bash
# Julia gate: Pkg.test (incl. Aqua + JET) with coverage, Coverage.jl lines must be 100, JuliaFormatter no diff.
# Other Julia packages under julia/ get Pkg.test (incl. JET) and the format check.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)" || exit 1
depot="${ADS_JULIA_DEPOT:-}"
if [ -n "$depot" ]; then export JULIA_DEPOT_PATH="$depot"; fi
pkg="$root/julia/AgenticDS.jl"
gate="$root/julia/gate"
cd "$root" || exit 1
find "$pkg" -name '*.cov' -delete
julia --project="$gate" -e 'using Pkg; Pkg.instantiate()'
julia --project="$pkg" -e 'using Pkg; Pkg.instantiate()'
julia --project="$pkg" --inline=no -e 'using Pkg; Pkg.test(coverage = true)'
julia --project="$gate" "$root/scripts/julia-coverage.jl" "$pkg"
julia --project="$gate" "$root/scripts/julia-format.jl" "$pkg"
find "$pkg" -name '*.cov' -delete
for e in "$pkg"/examples/*/run.jl; do julia --project="$pkg" "$e" > /dev/null; done
echo "examples OK"
for p in "$root"/julia/*/; do
  p="${p%/}"
  [ -f "$p/Project.toml" ] || continue
  case "$p" in "$pkg" | "$gate") continue ;; esac
  julia --project="$p" -e 'using Pkg; Pkg.instantiate()'
  julia --project="$p" --inline=no -e 'using Pkg; Pkg.test()'
  scripts/julia-format.sh "$p"
done
echo "gate-julia OK"
