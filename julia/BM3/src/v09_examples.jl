hits(cm) = sum(cm[i, i] for i = 1:3)
function matrix(t)
    pred = predict(fit_tree(t), t.X[t.test, :])
    return V05.confusion(t.y[t.test], pred)
end
function tree_part()
    cm = matrix(task())
    println("classes: ", GOLD.classes)
    println("confusion: ", cm)
    println("accuracy: ", hits(cm) / sum(cm))
    return cm == GOLD.confusion
end
function kmeans_part()
    lab, obj = V06.lloyd(scaled()...)
    n = [count(==(k), lab) for k = 1:3]
    println("objective: ", obj)
    println("cluster sizes: ", n)
    return isapprox(obj, GOLD.objective) &&
           n == GOLD.sizes
end
function main()
    a = tree_part()
    b = kmeans_part()
    verdict(a & b)
end
