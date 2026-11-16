confusion(t, p) =
    [sum(t[p .== b] .== a) for a = 1:3, b = 1:3]
recall(cm) = [cm[i, i] / sum(cm[i, :]) for i = 1:3]
precision(cm) = [cm[i, i] / sum(cm[:, i]) for i = 1:3]
function show_matrix(cm)
    names, r = GOLD.classes, rnd.(recall(cm), 4)
    wide_row("truth / predicted", [names; "recall"])
    for i = 1:3
        wide_row(names[i], Any[cm[i, :]..., r[i]])
    end
    wide_row("precision", [rnd.(precision(cm), 4); ""])
end
function main()
    t = task()
    pred = predict(fit_tree(), t.X[t.test, :])
    cm = confusion(t.y[t.test], pred)
    show_matrix(cm)
    hit, n = sum(cm[i, i] for i = 1:3), sum(cm)
    print("test rows $n, correct $hit, ")
    println("errors $(n - hit)")
    verdict(cm == GOLD.confusion)
end
