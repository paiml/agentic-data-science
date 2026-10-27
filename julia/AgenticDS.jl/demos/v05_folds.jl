# Provable contract: ads-b-m2-v05-folds. Fixed-fold cv_rmse matches the golden and exceeds in-sample error.
using AgenticDS
using DataFrames
using JSON3
using Logging
global_logger(NullLogger())
root = joinpath(@__DIR__, "..", "..", "..")
d = na_policy(read_penguins(joinpath(root, "datasets", "penguins", "penguins.csv")))
folds = read_folds(joinpath(root, "datasets", "fixtures", "folds.csv"))
println("fold sizes: ", [count(==(k), folds) for k = 1:5])
ols = cv_rmse(d, folds, false)
sp = cv_rmse(d, folds, true)
cvs = round.([ols, sp]; digits = 3)
println("cv rmse (flipper, species): ", cvs)
b = ols_closed_form(d.flipper_length_mm, d.body_mass_g)
fit = b.intercept .+ b.slope .* d.flipper_length_mm
ins = regression_metrics(d.body_mass_g, fit).rmse
printstyled("insample ", round(ins; digits = 3), "  "; color = :cyan)
printstyled("cv ", round(ols; digits = 3), "\n"; color = :cyan)
g = JSON3.read(read(joinpath(root, "datasets", "golden", "p2.json"), String))
println("golden: ", (g.cv_rmse.ols, g.cv_rmse.species))
ok = ins < ols && isapprox(ols, g.cv_rmse.ols; atol = 1e-6)
ok = ok && isapprox(sp, g.cv_rmse.species; atol = 1e-6)
ok = ok && sort(unique(folds)) == 1:5
msg = ok ? "golden matched" : "MISMATCH"
printstyled("VERDICT: ", msg, "\n"; color = ok ? :green : :red, bold = true)
@assert ok
println("contract: ads-b-m2-v05-folds (cv 394.313 and 376.638 match golden) OK")
