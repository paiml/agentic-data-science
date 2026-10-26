# Provable contract: ads-b-m2-v03-red-first. A failing OLS @testset written first turns green.
using Test
ols(x, y) = (intercept = 0.0, slope = 0.0)
function t()
    @testset "ols" begin
        b = ols([1.0, 2.0, 3.0, 4.0], [3.0, 5.0, 7.0, 9.0])
        @test b.intercept ≈ 1.0
        @test b.slope ≈ 2.0
    end
    return nothing
end
red = try
    redirect_stdio(stdout = devnull, stderr = devnull) do
        t()
    end
    "unexpected pass"
catch e
    string("red: ", e.pass, " passed, ", e.fail, " failed")
end
printstyled(red, "\n"; color = :red, bold = true)
ols(x, y) = (b = [ones(length(x)) x] \ y; (; intercept = b[1], slope = b[2]))
println("impl: backslash")
t()
b = ols([1.0, 2.0, 3.0, 4.0], [3.0, 5.0, 7.0, 9.0])
ok = isapprox(b.intercept, 1.0; atol = 1e-9) && isapprox(b.slope, 2.0; atol = 1e-9)
msg = ok ? "the test turned green" : "STILL RED"
printstyled("VERDICT: ", msg, "\n"; color = ok ? :green : :red, bold = true)
@assert ok
println("contract: ads-b-m2-v03-red-first (0 passed 2 failed, then 2 passed) OK")
