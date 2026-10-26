using AgenticDS
using Aqua
using DataFrames
using JET
using JSON3
using Test

const ROOT = abspath(joinpath(@__DIR__, "..", "..", ".."))
const CSV_PATH =
    joinpath(ROOT, "datasets", "penguins", "penguins.csv")
const GOLDEN = JSON3.read(
    read(joinpath(ROOT, "datasets", "golden", "p1.json"), String),
)

@testset "AgenticDS P1" begin
    @testset "read_penguins" begin
        df = read_penguins(CSV_PATH)
        @test nrow(df) == 344
        @test eltype(df.bill_length_mm) == Union{Missing,Float64}
        @test eltype(df.year) == Int
    end

    @testset "na_policy" begin
        df = read_penguins(CSV_PATH)
        clean = na_policy(df)
        @test nrow(clean) == 342
        @test eltype(clean.body_mass_g) == Float64
        # a missing sex alone keeps the row (guards 344 -> 342)
        @test count(ismissing, clean.sex) > 0
        keep = DataFrame(;
            species = ["Adelie"],
            bill_length_mm = [1.0],
            bill_depth_mm = [2.0],
            flipper_length_mm = [3.0],
            body_mass_g = [4.0],
            sex = [missing],
        )
        @test nrow(na_policy(keep)) == 1
        # a missing value in any numeric column drops the row
        for col in NUMERIC_COLS
            one = copy(keep)
            one[!, col] = Union{Missing,Float64}[missing]
            @test nrow(na_policy(one)) == 0
        end
    end

    @testset "summarise_by_species matches golden p1.json" begin
        s = summarise_by_species(na_policy(read_penguins(CSV_PATH)))
        @test s.species == ["Adelie", "Chinstrap", "Gentoo"]
        for row in eachrow(s)
            g = GOLDEN.species[Symbol(row.species)]
            @test row.n == g.n
            for col in NUMERIC_COLS
                @test isapprox(
                    row[Symbol(col, "_mean")],
                    g[col].mean;
                    atol = 1e-9,
                )
                @test isapprox(
                    row[Symbol(col, "_sd")],
                    g[col].sd;
                    atol = 1e-9,
                )
            end
        end
    end

    @testset "summary_json round-trips to golden layout" begin
        s = summarise_by_species(na_policy(read_penguins(CSV_PATH)))
        out = JSON3.read(summary_json(s))
        @test collect(keys(out.species)) ==
              [:Adelie, :Chinstrap, :Gentoo]
        for sp in keys(GOLDEN.species)
            @test out.species[sp].n == GOLDEN.species[sp].n
            for col in NUMERIC_COLS
                @test isapprox(
                    out.species[sp][col].mean,
                    GOLDEN.species[sp][col].mean;
                    atol = 1e-9,
                )
                @test isapprox(
                    out.species[sp][col].sd,
                    GOLDEN.species[sp][col].sd;
                    atol = 1e-9,
                )
            end
        end
    end
end

@testset "Aqua" begin
    Aqua.test_all(AgenticDS)
end

@testset "JET" begin
    JET.test_package(AgenticDS; target_modules = (AgenticDS,))
end
