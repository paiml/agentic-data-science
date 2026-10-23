#!/usr/bin/env bash
# B-M3 video 05-confusion: the confusion matrix, truth in rows, equal to the golden
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
julia --project="$PKG" -e '
using AgenticDS, DataFrames, JSON3
g = JSON3.read(read("datasets/golden/p3.json", String))
d = na_policy(read_penguins("datasets/penguins/penguins.csv"))
split = read_split("datasets/fixtures/split.csv")
fit = fit_species_clf(d[split .== "train", :])
test = d[split .== "test", :]
pred = predict_species_clf(fit, test)
cm = confusion(test.species, pred, fit.classes)
println(rpad("truth \\ predicted", 18), join(lpad.(fit.classes, 11)))
for (i, c) in enumerate(fit.classes); println(rpad(c, 18), join(lpad.(cm[i, :], 11))); end
println("test rows ", sum(cm), ", correct ", sum(cm[i, i] for i in 1:3), ", errors ", sum(cm) - sum(cm[i, i] for i in 1:3))
for (i, c) in enumerate(fit.classes); println(rpad(c, 10), "recall ", round(cm[i, i] / sum(cm[i, :]); digits = 4), "  precision ", round(cm[i, i] / sum(cm[:, i]); digits = 4)); end
@assert cm == permutedims(reduce(hcat, g.confusion))
@assert sum(cm) == nrow(test) == 85 && cm[2, 3] == 1 && cm[3, 2] == 1
println("contract: b-m3 confusion matrix equals the golden and sums to 85 OK")'
