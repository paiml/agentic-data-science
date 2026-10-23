#!/usr/bin/env bash
# B-M2 video 06-mlj: an MLJ LinearRegressor machine, fit!, fitted_params, parity with the golden
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
julia --project="$PKG" -e '
using AgenticDS, MLJBase, MLJLinearModels, JSON3, Logging; global_logger(NullLogger())
d = na_policy(read_penguins("datasets/penguins/penguins.csv"))
X = AgenticDS.species_design(d); y = Float64.(d.body_mass_g)
mach = machine(MLJLinearModels.LinearRegressor(), X, y)
println("machine before fit!: ", isdefined(mach, :fitresult) ? "fitted" : "no fitresult yet")
fit!(mach, verbosity = 0)
fp = fitted_params(mach)
println("intercept ", round(fp.intercept; digits = 3))
for (name, v) in fp.coefs; println(rpad(String(name), 20), round(v; digits = 3)); end
g = JSON3.read(read("datasets/golden/p2.json", String))
sp = fit_species(d)
println("fit_species keys: ", collect(keys(sp)))
@assert isdefined(mach, :fitresult)
@assert isapprox(fp.intercept, g.species_model[Symbol("(Intercept)")]; atol = 1e-8)
@assert all(isapprox(sp[k], g.species_model[Symbol(k)]; atol = 1e-8) for k in keys(sp))
@assert round(sp["speciesGentoo"]; digits = 3) == 266.81
println("contract: b-m2 MLJ machine, fit! and fitted_params match the species golden OK")'
