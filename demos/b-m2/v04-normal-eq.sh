#!/usr/bin/env bash
# B-M2 video 04-normal-eq: normal equations, backslash and the package function against the golden
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
julia --project="$PKG" -e '
using AgenticDS, JSON3, LinearAlgebra
d = na_policy(read_penguins("datasets/penguins/penguins.csv"))
x = d.flipper_length_mm; y = d.body_mass_g
X = [ones(length(x)) x]
b_ne = (X'"'"'X) \ (X'"'"'y)
b_qr = X \ y
b_pk = ols_closed_form(x, y)
g = JSON3.read(read("datasets/golden/p2.json", String))
show(name, a, s) = println(rpad(name, 18), "intercept ", round(a[1]; digits = 4), "  slope ", round(a[2]; digits = 4), "  |diff from golden| ", round(max(abs(a[1] - g.ols.intercept), abs(a[2] - g.ols.slope)); sigdigits = 1) < 1e-8 ? "< 1e-8" : "too large")
show("normal equations", b_ne, 0)
show("backslash (QR)", b_qr, 0)
show("ols_closed_form", [b_pk.intercept, b_pk.slope], 0)
println("cond(X) = ", round(cond(X); sigdigits = 2), " but cond(X'"'"'X) = ", round(cond(X'"'"'X); sigdigits = 2), ": QR avoids squaring it")
@assert all(isapprox.(b_ne, [g.ols.intercept, g.ols.slope]; atol = 1e-6))
@assert all(isapprox.(b_qr, [g.ols.intercept, g.ols.slope]; atol = 1e-8))
@assert isapprox(b_pk.intercept, g.ols.intercept; atol = 1e-8) && isapprox(b_pk.slope, g.ols.slope; atol = 1e-8)
println("contract: b-m2 normal equations, backslash and ols_closed_form all match the golden OK")'
