function mut(v, from, to)
    src = read(joinpath(ROOT, "src", v * ".jl"), String)
    occursin(from, src) || error("no match: $from")
    box = Module()
    Core.eval(box, :(using BM3: sq, mean, sizes))
    include_string(box, replace(src, from => to))
    go(f, a...) = Core.eval(box, Expr(:call, f, a...))
    return go
end
function no_update()
    go = mut("v06_kmeans", "mean(A; dims = 1)", "o")
    return !(isapprox(
        go(:lloyd, scaled()...)[2],
        GOLD.objective,
    ))
end
function later_tie()
    go = mut("v03_split", "gain > b", "gain >= b")
    return go(:best_cut, 1.0:4, [1, 2, 1, 2])[2] == 3.5
end
function main()
    a = hit_line("no centroid update", no_update())
    b = hit_line("later cut wins a tie", later_tie())
    verdict(a & b, "caught")
end
