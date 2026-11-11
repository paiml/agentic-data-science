const MSG = "typed ingest, 344 -> 342, sex gaps kept"
function types(raw)
    for c in names(raw)
        println(rpad(c, 18), eltype(raw[!, c]))
    end
end
function gaps(raw)
    miss(c) = count(ismissing, raw[!, c])
    bad = filter(c -> miss(c) > 0, names(raw))
    println("missing: ", [c => miss(c) for c in bad])
end
function main()
    raw = read_penguins(joinpath(DATA, "penguins.csv"))
    clean = na_policy(raw)
    types(raw)
    gaps(raw)
    n, m = nrow(raw), nrow(clean)
    k = count(ismissing, clean.sex)
    println("rows $n -> $m; sex still missing in $k")
    verdict((n, m, k) == (344, 342, 9), MSG)
end
