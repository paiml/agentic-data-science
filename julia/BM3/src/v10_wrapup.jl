function tree_ok()
    cm = V09.matrix(task())
    return cm == GOLD.confusion && V09.hits(cm) == 83
end
function kmeans_ok()
    lab, obj = V06.lloyd(scaled()...)
    n = [count(==(k), lab) for k = 1:3]
    return isapprox(obj, GOLD.objective) &&
           n == GOLD.sizes
end
function golden_line(g = GOLD)
    print("golden accuracy ", g.accuracy, ", ")
    print("confusion ", g.confusion, ", ")
    print("k-means ", rnd(g.objective, 4))
    println(" / ", g.sizes)
end
function main()
    a = contract(tree_ok())
    b = contract(kmeans_ok())
    golden_line()
    verdict(a & b)
end
