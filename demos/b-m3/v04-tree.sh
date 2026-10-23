#!/usr/bin/env bash
# B-M3 video 04-tree: CART parameters minsplit 20, minbucket 7, cp 0.01; the tree and its accuracy against the golden
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
julia --project="$PKG" -e '
using AgenticDS, DataFrames, JSON3
println("minsplit ", AgenticDS.MINSPLIT, ", minbucket ", AgenticDS.MINBUCKET, ", cp ", AgenticDS.CP)
g = JSON3.read(read("datasets/golden/p3.json", String))
d = na_policy(read_penguins("datasets/penguins/penguins.csv"))
split = read_split("datasets/fixtures/split.csv")
fit = fit_species_clf(d[split .== "train", :])
t = fit.tree
show_node(n::AgenticDS.Leaf, ind) = println(ind, "-> ", fit.classes[n.label])
function show_node(n::AgenticDS.Split, ind)
    println(ind, NUMERIC_COLS[n.var], " < ", n.cut)
    show_node(n.left, ind * "  "); println(ind, "else"); show_node(n.right, ind * "  ")
end
show_node(t, "")
test = d[split .== "test", :]
pred = predict_species_clf(fit, test)
acc = accuracy(test.species, pred)
println("test accuracy ", acc, " (", count(pred .== test.species), " of ", nrow(test), "), golden ", g.accuracy)
@assert AgenticDS.MINSPLIT == 20 && AgenticDS.MINBUCKET == 7 && AgenticDS.CP == 0.01
@assert t.var == 3 && t.cut == 207.5 && t.left.var == 1 && t.left.cut == 43.35
@assert isapprox(acc, g.accuracy; atol = 1e-12)
println("contract: b-m3 tree splits on flipper then bill length and accuracy equals the golden OK")'
