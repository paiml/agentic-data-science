# Provable contract: ads-b-m2-v01-ticket. The ticket's golden numbers show the species model beats flipper-only.
using JSON3
root = joinpath(@__DIR__, "..", "..", "..")
c = readlines(joinpath(root, "contracts", "ads-julia-p2-v1.yaml"))
foreach(println, filter(l -> occursin("ads-julia-p2-v1", l), c))
foreach(println, filter(l -> occursin(r"FIXED_FOLDS|NO_LEAKAGE|CAN_FAIL", l), c))
g = JSON3.read(read(joinpath(root, "datasets", "golden", "p2.json"), String))
flipper = round(g.cv_rmse.ols; digits = 3)
species = round(g.cv_rmse.species; digits = 3)
@info "golden cv_rmse" flipper_only = flipper with_species = species
ok = species == 376.638 && species < flipper
msg = ok ? "species model beats flipper-only out of fold" : "MISMATCH"
printstyled("VERDICT: ", msg, "\n"; color = ok ? :green : :red, bold = true)
@assert ok
println("contract: ads-b-m2-v01-ticket (species 376.638 < flipper-only 394.313) OK")
