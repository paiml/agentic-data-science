using AgenticDS
using DataFrames
using JSON3
using Test

const CSV_PATH = joinpath(@__DIR__, "..", "data", "penguins-mini.csv")

# Hand-checkable fixture: Adelie has 3 complete rows + 1 all-NA row, Gentoo 2, Chinstrap 3.
const EXPECT = Dict(
    "Adelie" => (n = 3, bill_length_mm = (40.0, 1.0), bill_depth_mm = (19.0, 1.0),
        flipper_length_mm = (185.0, 5.0), body_mass_g = (3700.0, 100.0)),
    "Chinstrap" => (n = 3, bill_length_mm = (50.0, 2.0), bill_depth_mm = (19.0, 1.0),
        flipper_length_mm = (195.0, 5.0), body_mass_g = (3700.0, 200.0)),
    "Gentoo" => (n = 2, bill_length_mm = (48.0, sqrt(8.0)), bill_depth_mm = (15.0, sqrt(2.0)),
        flipper_length_mm = (220.0, sqrt(50.0)), body_mass_g = (4900.0, sqrt(80000.0))),
)

@testset "Lab: penguin summary" begin
    @testset "read_penguins (given)" begin
        df = read_penguins(CSV_PATH)
        @test nrow(df) == 9
        @test eltype(df.bill_length_mm) == Union{Missing,Float64}
        @test count(ismissing, df.bill_length_mm) == 1
    end

    @testset "TODO 1 na_policy drops rows with a missing measurement" begin
        clean = na_policy(read_penguins(CSV_PATH))
        @test nrow(clean) == 8
        for col in NUMERIC_COLS
            @test eltype(clean[!, col]) == Float64
        end
    end

    @testset "TODO 1 na_policy keeps a row whose only gap is sex" begin
        clean = na_policy(read_penguins(CSV_PATH))
        @test count(ismissing, clean.sex) == 1
        keep = DataFrame(; species = ["Adelie"], bill_length_mm = [1.0], bill_depth_mm = [2.0],
            flipper_length_mm = [3.0], body_mass_g = [4.0], sex = [missing])
        @test nrow(na_policy(keep)) == 1
    end

    @testset "TODO 1 na_policy: a gap in any one measurement drops the row" begin
        keep = DataFrame(; species = ["Adelie"], bill_length_mm = [1.0], bill_depth_mm = [2.0],
            flipper_length_mm = [3.0], body_mass_g = [4.0], sex = ["male"])
        for col in NUMERIC_COLS
            one = copy(keep)
            one[!, col] = Union{Missing,Float64}[missing]
            @test nrow(na_policy(one)) == 0
        end
    end

    @testset "TODO 2 summarise_by_species: species order and counts" begin
        s = summarise_by_species(na_policy(read_penguins(CSV_PATH)))
        @test s.species == ["Adelie", "Chinstrap", "Gentoo"]
        for row in eachrow(s)
            @test row.n == EXPECT[row.species].n
        end
    end

    @testset "TODO 2 summarise_by_species: means and SAMPLE sd (n-1)" begin
        s = summarise_by_species(na_policy(read_penguins(CSV_PATH)))
        for row in eachrow(s)
            for col in NUMERIC_COLS
                m, sd = EXPECT[row.species][col]
                @test isapprox(row[Symbol(col, "_mean")], m; atol = 1e-9)
                @test isapprox(row[Symbol(col, "_sd")], sd; atol = 1e-9)
            end
        end
    end

    @testset "TODO 3 summary_json: layout, order and values" begin
        s = summarise_by_species(na_policy(read_penguins(CSV_PATH)))
        out = JSON3.read(summary_json(s))
        @test collect(keys(out.species)) == [:Adelie, :Chinstrap, :Gentoo]
        for sp in keys(out.species)
            e = EXPECT[String(sp)]
            @test out.species[sp].n == e.n
            @test collect(keys(out.species[sp])) == [:n, NUMERIC_COLS...]
            for col in NUMERIC_COLS
                @test isapprox(out.species[sp][col].mean, e[col][1]; atol = 1e-9)
                @test isapprox(out.species[sp][col].sd, e[col][2]; atol = 1e-9)
            end
        end
    end
end
