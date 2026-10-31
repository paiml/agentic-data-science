r3(x) = round(x; digits = 3)
function sd_by_hand(x, k)
    ss = sum(abs2, x .- mean(x))
    return sqrt(ss / (length(x) - k))
end
function gentoo(d, s)
    x = d.body_mass_g[d.species .== "Gentoo"]
    sd = only(s.body_mass_g_sd[s.species .== "Gentoo"])
    hand, pop = sd_by_hand(x, 1), sd_by_hand(x, 0)
    return (summarise = sd, n_1 = hand, n = pop)
end
function main()
    path = joinpath(DATA, "penguins.csv")
    d = na_policy(read_penguins(path))
    s = summarise_by_species(d)
    show(
        stdout,
        select(s, :species, :n, r"body_mass");
        summary = false,
    )
    println()
    sds = gentoo(d, s)
    println("Gentoo body mass sd: ", map(r3, sds))
    ok = s.n == [151, 68, 123]
    ok &= isapprox(sds.summarise, sds.n_1; atol = 1e-12)
    ok &= abs(sds.n_1 - sds.n) > 1e-3
    verdict(ok, "counts 151/68/123 and sd uses n-1")
end
