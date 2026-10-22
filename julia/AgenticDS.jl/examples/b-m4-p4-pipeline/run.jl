# P4 (b): Wine Quality pipeline and report artifact, checked against the golden.
# Usage: julia --project=julia/AgenticDS.jl julia/AgenticDS.jl/examples/b-m4-p4-pipeline/run.jl
# Provable contract: ads-julia-p4-v1, rows and split sizes exact, RMSE and R2 within 1e-6.
using AgenticDS
using JSON3
dir = joinpath("datasets", "wine-quality")
res = pipeline_wine(
    joinpath(dir, "winequality-red.csv"),
    joinpath(dir, "winequality-white.csv"),
)
println(res)
golden = JSON3.read(read(joinpath("datasets", "golden", "p4.json"), String))
@assert res["n_rows"] == golden.n_rows
@assert res["n_train"] == golden.n_train && res["n_test"] == golden.n_test
@assert isapprox(res["rmse"], golden.rmse; atol = 1e-6)
@assert isapprox(res["r2"], golden.r2; atol = 1e-6)
mktempdir() do tmp
    println(read(report_ttl(res, joinpath(tmp, "wine-report.ttl")), String))
end
println("contract: ads-julia-p4-v1 OK")
