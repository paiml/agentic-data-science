counts(y, rows) = [count(==(k), y[rows]) for k = 1:3]
function grow(X, y, rows, root_err)
    n = counts(y, rows)
    leaf, err = Leaf(argmax(n)), sum(n) - maximum(n)
    (sum(n) < MINSPLIT || err == 0) && return leaf, err
    b = best_split(X, y, rows)
    b.var == 0 && return leaf, err
    go = X[rows, b.var] .< b.cut
    l, le = grow(X, y, rows[go], root_err)
    r, re = grow(X, y, rows[.!go], root_err)
    err - (le + re) < CP * root_err && return leaf, err
    return Split(b.var, b.cut, l, r), le + re
end
function report(tree)
    hit, n = score(tree)
    print("test accuracy $(hit / n) ($hit of $n), ")
    println("golden $(GOLD.accuracy)")
    return abs(hit / n - GOLD.accuracy) < 1e-12
end
function main()
    println(settings())
    tree = fit_tree()
    show_tree(tree)
    verdict(report(tree) & (outline(tree) == SHAPE))
end
