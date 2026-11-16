const GENERATOR = "AgenticDS.pipeline_wine"
function report_ttl(res, path)
    rmse = @sprintf("%.10f", res.rmse)
    body = [
        """  ads:schemaVersion "1" ;""",
        """  ads:generatedBy "$GENERATOR" ;""",
        """  ads:rmse "$rmse"^^xsd:decimal ;""",
        """  ads:rows "$(res.rows)"^^xsd:integer .""",
    ]
    open(path, "w") do io
        foreach(l -> println(io, l), [TTL_HEAD; body])
    end
    return path
end
strip_gen(f) =
    filter(!contains("generatedBy"), readlines(f))
same_ttl(a, b) = strip_gen(a) == strip_gen(b)
function main()
    res = pipeline_wine(RED, WHITE)
    path = report_ttl(res, tempname())
    foreach(println, eachline(path))
    ok = same_ttl(path, R_TTL)
    verdict(ok, "report_ttl matches the R artifact")
end
