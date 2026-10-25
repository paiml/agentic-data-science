# P1 (a): typed ingest and the missing-value policy.
# Usage: julia --project=julia/AgenticDS.jl julia/AgenticDS.jl/examples/b-m1-p1/run.jl [path/to/penguins.csv]
using AgenticDS
path = isempty(ARGS) ? joinpath("datasets", "penguins", "penguins.csv") : ARGS[1]
penguins = read_penguins(path)
clean = na_policy(penguins)
println("rows: ", size(penguins, 1), ", after NA policy: ", size(clean, 1))
@assert size(penguins, 1) == 344 && size(clean, 1) == 342
println("contract: ads-julia-p1-v1 OK")
