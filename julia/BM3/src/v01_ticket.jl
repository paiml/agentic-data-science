function ticket_data(t)
    n, tr, te = length(t.y), sum(t.train), sum(t.test)
    println("clean rows $n; split train $tr, test $te")
    return (n, tr, te) == (342, 257, 85)
end
function ticket_confusion(g)
    cm = g.confusion
    d = sum(cm[i, i] for i = 1:3)
    print("golden confusion sums to $(sum(cm)); ")
    println("diagonal $d; accuracy $(g.accuracy)")
    return sum(cm) == 85 &&
           abs(d / 85 - g.accuracy) < 1e-12
end
function ticket_kmeans(g)
    print("golden k-means objective ")
    println(rnd(g.objective, 4), ", sizes ", g.sizes)
    return sum(g.sizes) == 342
end
function main()
    ok = checksum_ok()
    println("penguins.csv: ", ok ? "OK" : "FAILED")
    ok &= ticket_data(task())
    ok &= ticket_confusion(GOLD)
    verdict(ok & ticket_kmeans(GOLD))
end
