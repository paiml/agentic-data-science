#!/usr/bin/env bash
# Julia gate: Pkg.test (incl. Aqua + JET) with coverage, Coverage.jl lines must be 100, JuliaFormatter no diff.
# Scene projects under julia/ (not AgenticDS.jl) get Pkg.test (JET) and the format check
# of the whole package (scripts/julia-format.sh).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
[ -z "${ADS_JULIA_DEPOT:-}" ] || export JULIA_DEPOT_PATH="$ADS_JULIA_DEPOT"
pkg="$root/julia/AgenticDS.jl"
gate="$root/julia/gate"
cd "$root"
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
total > 0 && covered == total || (println("coverage FAIL: measured nothing or gaps"); exit(1))
' "$pkg"
scripts/julia-format.sh "$pkg"
find "$pkg" -name '*.cov' -delete
for e in "$pkg"/examples/*/run.jl; do julia --project="$pkg" "$e" > /dev/null; done
echo "examples OK"
# Other Julia packages (scene projects): Pkg.test (incl. JET) + JuliaFormatter no diff.
for p in "$root"/julia/*/; do
  p="${p%/}"
  [ -f "$p/Project.toml" ] || continue
  case "$p" in "$pkg" | "$gate") continue ;; esac
  julia --project="$p" -e 'using Pkg; Pkg.instantiate()'
  julia --project="$p" --inline=no -e 'using Pkg; Pkg.test()'
  scripts/julia-format.sh "$p"
done
# Scene v07 runs its own shell commands (format, native Pkg.test) live;
# that gate runs here, after the package Pkg.test, never inside it.
julia julia/BM2/gate/v07.jl
echo "gate-julia OK"
