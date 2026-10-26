function mutate(f)
    old = only(filter(contains("beta ="), readlines(f)))
    new = replace(old, "s.train" => "s.test")
    println("mutation in ", basename(f))
    foreach(println, ("<" * old, ">" * new))
    return replace(read(f, String), old => new)
end
ttl_ok(r) = same_ttl(report_ttl(r, tempname()), R_TTL)
function suite(res, g)
    return [
        "rmse golden" => near(res.rmse, g.rmse),
        "r2 golden" => near(res.r2, g.r2),
        "leak test" => res.rmse >= g.rmse,
        "report_ttl" => ttl_ok(res),
    ]
end
function main()
    res = run_mutant(mutate(V04_FILE))
    bad = [n for (n, ok) in suite(res, golden()) if !ok]
    foreach(failed, bad)
    println("failed: $(length(bad))  errored: 0")
    verdict(length(bad) == 4, "the leaky fit is caught")
end
