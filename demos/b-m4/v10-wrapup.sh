#!/usr/bin/env bash
# B-M4 video 10-wrapup: the Gate Report idea, every claim re-checked from the artifacts
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
julia --project="$PKG" -e '
using AgenticDS, JSON3
g = JSON3.read(read("datasets/golden/p4.json", String))
r = pipeline_wine("datasets/wine-quality/winequality-red.csv", "datasets/wine-quality/winequality-white.csv")
claims = [
  "ticket: 6497 rows split 5198 and 1299" => (r["n_rows"], r["n_train"], r["n_test"]) == (g.n_rows, g.n_train, g.n_test),
  "validate first: bad data never reaches the fit" => try validate_wine(AgenticDS.DataFrames.DataFrame(quality = [11], color = ["red"])); false catch e; e isa ArgumentError end,
  "held-out RMSE equals the golden" => isapprox(r["rmse"], g.rmse; atol = 1e-6),
  "held-out R2 equals the golden" => isapprox(r["r2"], g.r2; atol = 1e-6),
]
for (c, ok) in claims println(ok ? "PASS " : "FAIL ", c) end
println("Gate Report: ", count(last, claims), " of ", length(claims), " claims hold; green gates do not prove the model is good")
@assert all(last, claims)
println("contract: b-m4 the Gate Report claims all hold OK")'
