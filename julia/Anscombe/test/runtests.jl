using Anscombe
using JET
using Test

const DATA = joinpath(@__DIR__, "..", "..", "..", "data", "anscombe.csv")

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

    @testset "four sets, one fit" begin
        for (x, y) in q
            a, b = ols(x, y)
            @test isapprox(a, 3.0; atol = 0.01)
            @test isapprox(b, 0.5; atol = 0.001)
            @test isapprox(correlation(x, y), 0.816; atol = 0.001)
        end
    end

    @testset "report" begin
        r = report(q)
        @test length(r) == 4
        @test r[1] == "set 1: n=11 intercept=3.0 slope=0.5 r=0.816"
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
