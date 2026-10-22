# P2 (b): MLJ species model and fixed-fold CV, checked against the golden.
# Usage: julia --project=julia/AgenticDS.jl julia/AgenticDS.jl/examples/b-m2-p2-cv/run.jl
using AgenticDS
using JSON3
d = na_policy(read_penguins(joinpath("datasets", "penguins", "penguins.csv")))
folds = read_folds(joinpath("datasets", "fixtures", "folds.csv"))
println(fit_species(d))
ols = cv_rmse(d, folds, false)
species = cv_rmse(d, folds, true)
println("cv_rmse (ols): ", ols)
println("cv_rmse (species): ", species)
golden = JSON3.read(read(joinpath("datasets", "golden", "p2.json"), String))
@assert isapprox(ols, golden.cv_rmse.ols; atol = 1e-6)
@assert isapprox(species, golden.cv_rmse.species; atol = 1e-6)
println("contract: ads-julia-p2-v1 OK")
