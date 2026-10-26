# Provable contract: ads-b-m2-v02-design. The OLS design is 342 x 2 and the species dummies leave Adelie as baseline.
using AgenticDS
using DataFrames
root = joinpath(@__DIR__, "..", "..", "..")
d = na_policy(read_penguins(joinpath(root, "datasets", "penguins", "penguins.csv")))
println("rows after NA policy: ", nrow(d))
x = d.flipper_length_mm
y = d.body_mass_g
X = [ones(length(x)) x]
println("design size: ", size(X))
println("first rows of X: ", X[1:3, :])
S = AgenticDS.species_design(d)
println("species columns: ", names(S))
n = (Int(sum(S.speciesChinstrap)), Int(sum(S.speciesGentoo)))
na = count(==("Adelie"), d.species)
println("counts (Chinstrap, Gentoo, Adelie): ", n, " ", na)
ok = size(X) == (342, 2) && all(X[:, 1] .== 1.0) && n == (68, 123) && na == 151
msg = ok ? "design matrices are right, Adelie is baseline" : "MISMATCH"
printstyled("VERDICT: ", msg, "\n"; color = ok ? :green : :red, bold = true)
@assert ok
println("contract: ads-b-m2-v02-design (342 x 2, dummies 68 and 123, Adelie base) OK")
