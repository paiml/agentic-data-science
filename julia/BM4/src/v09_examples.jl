# Provable contract: ads-julia-p4-v1 (rows, 1e-6)
const OK = "contract: ads-julia-p4-v1 OK"
function pipeline_example(io)
    res, g = pipeline_wine(RED, WHITE), golden()
    @assert res.rows == g.rows
    @assert res.train == g.train && res.test == g.test
    @assert near(res.rmse, g.rmse)
    @assert near(res.r2, g.r2)
    println(io, res)
    print(io, read(report_ttl(res, tempname()), String))
    println(io, OK)
end
function bench_example(io)
    println(io, bench_wine(read_wine(RED, WHITE)))
    println(io, OK)
end
shown(l) = occursin(r"Artifact|ads:rows", l)
function main()
    out = captured(pipeline_example)
    bench = captured(bench_example)
    foreach(println, filter(shown, out))
    ok = last(out) == OK && last(bench) == OK
    verdict(ok, "both examples keep their contracts")
end
