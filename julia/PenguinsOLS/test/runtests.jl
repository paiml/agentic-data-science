using PenguinsOLS
using DataFrames
using GLM
using JET
using Test

const CSV_PATH =
    joinpath(@__DIR__, "..", "data", "penguins.csv")
# datasets/golden/p2.json (ads-julia-p2-ols-demo-v1): closed-form OLS,
# 342 rows
function read_raw()
    csv = PenguinsOLS.CSV
    return csv.read(
        CSV_PATH,
        DataFrame;
        missingstring = "NA",
    )
end
const GOLD_INTERCEPT = -5780.83135807716
const GOLD_SLOPE = 49.6855664061006

@testset "JET" begin
    JET.test_package(
        PenguinsOLS;
        target_modules = (PenguinsOLS,),
    )
end

@testset "PenguinsOLS" begin
    df = load_penguins(CSV_PATH)
    model = fit_ols(df)

    @testset "drop_na only on the model columns" begin
        @test nrow(df) == 342
        @test nrow(dropmissing(read_raw())) == 333
    end

    @testset "fit matches golden" begin
        @test isapprox(
            coef(model)[1],
            GOLD_INTERCEPT;
            atol = 1e-6,
        )
        @test isapprox(
            coef(model)[2],
            GOLD_SLOPE;
            atol = 1e-8,
        )
        @test round.(coef(model); digits = 2) ==
              [-5780.83, 49.69]
    end

    @testset "residuals sum to zero (OLS with intercept)" begin
        @test abs(sum(residuals(model))) < 1e-6
    end

    @testset "can fail: a wrong row policy breaks the golden" begin
        wrong = dropmissing(read_raw())
        slope = coef(fit_ols(wrong))[2]
        @test !isapprox(slope, GOLD_SLOPE; atol = 1e-8)
    end

    @testset "plot is written" begin
        path = joinpath(mktempdir(), "plot.png")
        save_plot(df, model, path)
        @test filesize(path) > 10_000
        hdr = read(path, 24)
        w = Int(
            ntoh(reinterpret(UInt32, hdr[17:20])[1]),
        )
        h = Int(
            ntoh(reinterpret(UInt32, hdr[21:24])[1]),
        )
        @test (w, h) == (720, 1080)
    end

    @testset "main prints the verdict" begin
        out = tempname()
        cd(mktempdir()) do
            cp(joinpath(@__DIR__, "..", "data"), "data")
            open(out, "w") do io
                redirect_stdout(() -> main(), io)
            end
        end
        text = read(out, String)
        @test occursin("rows = 342", text)
        @test occursin("golden: true", text)
    end
end

@testset "scene manifest" begin
    root = joinpath(@__DIR__, "..")
    m = Dict{String,String}()
    for l in eachline(
        joinpath(root, "scenes", "v04-normal-eq.scene"),
    )
        k, v = split(l, " = "; limit = 2)
        m[k] = v
    end
    src = joinpath(root, m["file"])
    lines = readlines(src)
    @test length(lines) <= 25
    @test all(l -> length(l) <= 56, lines)
    @test !occursin(Char(92), read(src, String))
    ticks = map(split(m["ticks"], ",")) do s
        a, b = parse.(Int, split(s, "-"))
        return (a, b)
    end
    @test 4 <= length(ticks) <= 6
    @test all(t -> 1 <= t[1] <= t[2], ticks)
    @test all(
        i -> ticks[i][2] < ticks[i + 1][1],
        1:(length(ticks) - 1),
    )
    @test ticks[end][2] <= length(lines)
    for (a, b) in ticks
        @test !isempty(lines[a])
        @test !startswith(lines[a], " ")
        @test !startswith(lines[a], "end")
        ex = Meta.parseall(join(lines[a:b], "\n"))
        @test !any(
            e ->
                e isa Expr &&
                e.head in (:error, :incomplete),
            ex.args,
        )
    end
    # vimrc.demo F2.. jump to the first line of each tick
    vimrc = read(joinpath(root, "vimrc.demo"), String)
    keys = [
        parse(Int, mm[1]) for mm in
        eachmatch(r"call Tick\((\d+)\)", vimrc)
    ]
    @test keys == first.(ticks)
    # can fail: a drifted vimrc is a different list
    @test keys != [1, 3, 4, 7, 11, 20, 23, 24]
end
