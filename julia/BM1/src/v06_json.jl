const KEYS =
    [(c, t) for c in NUMERIC_COLS for t in (:mean, :sd)]
got(r) = [r[Symbol(c, "_", t)] for (c, t) in KEYS]
want(g) = [g[c][t] for (c, t) in KEYS]
function main()
    path = joinpath(DATA, "penguins.csv")
    s = summarise_by_species(
        na_policy(read_penguins(path)),
    )
    println("species n  mean, sd of the four columns")
    ok = true
    for r in eachrow(s)
        g = gold_sp(r.species)
        ok &=
            r.n == g.n &&
            isapprox(got(r), want(g); atol = 1e-9)
        println(
            rpad(r.species, 10),
            r.n,
            " ",
            r2.(got(r)),
        )
    end
    verdict(ok, "profile equals the golden")
end
