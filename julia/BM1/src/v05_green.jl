const PKG = joinpath(ROOT, "julia", "AgenticDS.jl")
const CODE = "using Pkg; Pkg.test()"
function run_tests(pkg)
    cmd = julia_cmd(pkg, "-e", CODE)
    return test_rows(capture_cmd(cmd))
end
function show_rows(rows)
    for r in rows
        println(
            rpad(r.name, 14),
            "| ",
            r.pass,
            "  ",
            r.total,
        )
    end
end
function main()
    rows = run_tests(PKG)
    show_rows(rows)
    ok = length(rows) == 3
    ok &= all(r -> r.pass == r.total, rows)
    verdict(ok, "tests, Aqua and JET green")
end
