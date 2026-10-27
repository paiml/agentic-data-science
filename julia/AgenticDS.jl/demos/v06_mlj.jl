# Provable contract: ads-b-m2-v06-mlj. An MLJ machine fits the species golden model.
using AgenticDS
using MLJBase
using MLJLinearModels
using JSON3
using Logging
global_logger(NullLogger())
root = joinpath(@__DIR__, "..", "..", "..")
d = na_policy(read_penguins(joinpath(root, "datasets", "penguins", "penguins.csv")))
X = AgenticDS.species_design(d)
y = Float64.(d.body_mass_g)
mach = machine(MLJLinearModels.LinearRegressor(), X, y)
println("before fit!: ", isdefined(mach, :fitresult) ? "fitted" : "no fitresult yet")
fit!(mach, verbosity = 0)
fp = fitted_params(mach)
println("intercept ", round(fp.intercept; digits = 3))
for (name, v) in fp.coefs
    println(rpad(String(name), 20), round(v; digits = 3))
end
g = JSON3.read(read(joinpath(root, "datasets", "golden", "p2.json"), String))
gold = g.species_model
sp = fit_species(d)
ok_i = isapprox(fp.intercept, gold[Symbol("(Intercept)")]; atol = 1e-8)
ok_c = length(fp.coefs) == 3
ok_c = ok_c && all(isapprox(v, gold[name]; atol = 1e-8) for (name, v) in fp.coefs)
ok_s = all(isapprox(sp[k], gold[Symbol(k)]; atol = 1e-8) for k in keys(sp))
@assert isdefined(mach, :fitresult)
@assert ok_i && ok_c && ok_s
@assert round(sp["speciesGentoo"]; digits = 3) == 266.81
println("contract: ads-b-m2-v06-mlj fitted_params match the golden OK")
