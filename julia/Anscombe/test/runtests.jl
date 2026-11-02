using Anscombe
using JET
using Test

const DATA = joinpath(@__DIR__, "..", "..", "..", "data", "anscombe", "anscombe.csv")

@testset "JET" begin
    JET.test_package(Anscombe; target_modules = (Anscombe,))
end

@testset "Anscombe" begin
    q = load_quartet(DATA)

    @testset "shape of the pinned data" begin
        @test length(q) == 4
        @test all(length(x) == 11 && length(y) == 11 for (x, y) in q)
        @test q[4][1][8] == 19.0
    end

    # Sample variances, computed from the data in Base (no Statistics dependency); reference values from the pinned CSV.
    samplevar(v) = sum((v .- sum(v) / length(v)) .^ 2) / (length(v) - 1)
    # Per-set (intercept, slope, r) of the published quartet, to the precision the data pins.
    fits(x, y) =
        isapprox(ols(x, y)[1], 3.0; atol = 0.003) &&
        isapprox(ols(x, y)[2], 0.5; atol = 0.0005) &&
        isapprox(correlation(x, y), 0.8163; atol = 0.0003)

    @testset "four sets, one fit" begin
        for (x, y) in q
            a, b = ols(x, y)
            @test isapprox(a, 3.0; atol = 0.003)
            @test isapprox(b, 0.5; atol = 0.0005)
            @test isapprox(correlation(x, y), 0.8163; atol = 0.0003)
            @test fits(x, y)
        end
    end

    @testset "variances of all four sets" begin
        vy = [4.127269, 4.127629, 4.122620, 4.123249]
        for (k, (x, y)) in enumerate(q)
            @test isapprox(samplevar(x), 11.0; atol = 1e-9)
            @test isapprox(samplevar(y), vy[k]; atol = 1e-5)
        end
    end

    @testset "a perturbed value goes RED" begin
        for (x, y) in q
            @test fits(x, y)
            for i in eachindex(y)
                p = copy(y)
                p[i] += 1.0
                @test !fits(x, p)
            end
        end
    end

    @testset "report" begin
        r = report(q)
        @test length(r) == 4
        @test r[1] == "set I: n=11 mean_x=9.00 mean_y=7.50 slope=0.50 intercept=3.00 r=0.82"
    end

    @testset "plot and main write the same SVG" begin
        mktempdir() do d
            p = save_plot(q, joinpath(d, "a.svg"))
            @test occursin("<svg", read(p, String))
            redirect_stdout(devnull) do
                main(DATA, d)
            end
            @test read(joinpath(d, "plot.svg")) == read(p)
        end
    end
end
