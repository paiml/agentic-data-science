const FILE = joinpath(DATA, "penguins.csv")
const MSG = "ticket oracle matches data (344 -> 342)"
function checksum_ok()
    ok = sha_ok(FILE)
    println("penguins.csv: ", ok ? "OK" : "FAILED")
    return ok
end
function drops(raw, clean)
    n, m = nrow(raw), nrow(clean)
    println("raw rows $n, dropped $(n - m), clean $m")
    return (n, m) == (344, 342)
end
function golden_n(clean)
    sp = unique(clean.species)
    ns = [gold_sp(s).n for s in sp]
    println("golden n: ", ns, " sums to ", sum(ns))
    return ns == [sum(clean.species .== s) for s in sp]
end
function main()
    raw = read_penguins(FILE)
    clean = na_policy(raw)
    ok = checksum_ok() & drops(raw, clean)
    ok &= golden_n(clean)
    verdict(ok, MSG)
end
