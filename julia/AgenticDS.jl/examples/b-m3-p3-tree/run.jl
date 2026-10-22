# P3 (b): hand-written CART species classifier on the fixed split, checked against the golden.
# Usage: julia --project=julia/AgenticDS.jl julia/AgenticDS.jl/examples/b-m3-p3-tree/run.jl
# Provable contract: ads-julia-p3-v1, confusion matrix equals datasets/golden/p3.json exactly.
using AgenticDS
using JSON3
d = na_policy(read_penguins(joinpath("datasets", "penguins", "penguins.csv")))
split = read_split(joinpath("datasets", "fixtures", "split.csv"))
fit = fit_species_clf(d[split .== "train", :])
test = d[split .== "test", :]
pred = predict_species_clf(fit, test)
cm = confusion(test.species, pred, fit.classes)
println("classes: ", fit.classes)
println("confusion:\n", cm)
println("accuracy: ", accuracy(test.species, pred))
golden = JSON3.read(read(joinpath("datasets", "golden", "p3.json"), String))
@assert cm == reduce(hcat, golden.confusion)'
@assert isapprox(accuracy(test.species, pred), golden.accuracy; atol = 1e-12)
println("contract: ads-julia-p3-v1 OK")
