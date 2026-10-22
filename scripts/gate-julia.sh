#!/usr/bin/env bash
# Julia gate: Pkg.test (incl. Aqua + JET) with coverage, Coverage.jl lines must be 100, JuliaFormatter no diff.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
[ -z "${ADS_JULIA_DEPOT:-}" ] || export JULIA_DEPOT_PATH="$ADS_JULIA_DEPOT"
pkg="$root/julia/AgenticDS.jl"
gate="$root/julia/gate"
find "$pkg" -name '*.cov' -delete
julia --project="$gate" -e 'using Pkg; Pkg.instantiate()'
julia --project="$pkg" -e 'using Pkg; Pkg.instantiate()'
julia --project="$pkg" --inline=no -e 'using Pkg; Pkg.test(coverage = true)'
julia --project="$gate" -e '
using Coverage
c = process_folder(joinpath(ARGS[1], "src"))
covered, total = get_summary(c)
println("coverage: ", covered, "/", total)
for f in c
    for (i, n) in enumerate(f.coverage)
        n === 0 && println("UNCOVERED ", f.filename, ":", i)
    end
end
covered == total || exit(1)
' "$pkg"
julia --project="$gate" -e '
using JuliaFormatter
ok = format(ARGS[1]; verbose = false, overwrite = false)
println("format clean: ", ok)
ok || exit(1)
' "$pkg"
find "$pkg" -name '*.cov' -delete
echo "gate-julia OK"
