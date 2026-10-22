# P4 (b): benchmark two grouped-mean engines on the wine table.
# Usage: julia --project=julia/AgenticDS.jl julia/AgenticDS.jl/examples/b-m4-p4-bench/run.jl
# Provable contract: ads-julia-p4-v1, both engines return equal results; timings are never asserted.
using AgenticDS
dir = joinpath("datasets", "wine-quality")
wine =
    read_wine(joinpath(dir, "winequality-red.csv"), joinpath(dir, "winequality-white.csv"))
a = aggregate_groupby(wine)
b = aggregate_loop(wine)
@assert a.color == b.color && a.n == b.n
@assert isapprox(a.mean_quality, b.mean_quality; atol = 1e-12)
println(bench_wine(wine))
println("contract: ads-julia-p4-v1 OK")
