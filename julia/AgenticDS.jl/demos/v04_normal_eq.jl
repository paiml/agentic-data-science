# Provable contract: ads-b-m2-v04-normal-eq. Normal equations and backslash both match the golden OLS fit.
using AgenticDS
using JSON3
using LinearAlgebra
root = joinpath(@__DIR__, "..", "..", "..")
d = na_policy(read_penguins(joinpath(root, "datasets", "penguins", "penguins.csv")))
x = d.flipper_length_mm
y = d.body_mass_g
X = [ones(length(x)) x]
b_ne = (X'X) \ (X'y)
b_qr = X \ y
println("coef normal-eq: ", round.(b_ne; digits = 2))
println("coef backslash: ", round.(b_qr; digits = 2))
g = JSON3.read(read(joinpath(root, "datasets", "golden", "p2.json"), String))
gold = [g.ols.intercept, g.ols.slope]
println("coef golden:    ", round.(gold; digits = 2))
@info "condition numbers" cond_X = cond(X) cond_XtX = cond(X'X)
ok_ne = all(isapprox.(b_ne, gold; atol = 1e-6))
ok_qr = all(isapprox.(b_qr, gold; atol = 1e-8))
ok = ok_ne && ok_qr
msg = ok ? "normal equations and backslash match the golden" : "MISMATCH"
printstyled("VERDICT: ", msg, "\n"; color = ok ? :green : :red, bold = true)
@assert ok
