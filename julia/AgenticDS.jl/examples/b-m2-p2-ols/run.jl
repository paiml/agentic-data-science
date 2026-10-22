# P2 (a): closed-form OLS of body mass on flipper length, checked against the golden.
# Usage: julia --project=julia/AgenticDS.jl julia/AgenticDS.jl/examples/b-m2-p2-ols/run.jl
using AgenticDS
using JSON3
d = na_policy(read_penguins(joinpath("datasets", "penguins", "penguins.csv")))
b = ols_closed_form(d.flipper_length_mm, d.body_mass_g)
println(b)
golden = JSON3.read(read(joinpath("datasets", "golden", "p2.json"), String))
@assert isapprox(b.intercept, golden.ols.intercept; atol = 1e-8)
@assert isapprox(b.slope, golden.ols.slope; atol = 1e-8)
println("contract: ads-julia-p2-v1 OK")
