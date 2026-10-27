function check(m)
    x = collect(1.0:4.0)
    b = m.ols(x, 2 .* x .+ 1)
    return (b.intercept ≈ 1.0) + (b.slope ≈ 2.0)
end

function ols(x, y)
    b = backslash([ones(length(x)) x], y)
    return (; intercept = b[1], slope = b[2])
end

function green(m)
    Core.eval(m, Expr(:(=), :ols, ols))
    return invokelatest(check, m)
end

function main()
    m = Module(:Scratch)
    bad = red(check, m)
    println("red: $(bad.var) is not defined")
    n = green(m)
    println("green: $n of 2 tests pass")
    ok = bad isa UndefVarError && n == 2
    verdict(ok, "red, then green")
end
