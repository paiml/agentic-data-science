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

function within(lines)
    return length(lines) <= 25 &&
           maximum(length.(lines)) <= 56 &&
           !occursin(Char(92), join(lines))
end

@testset "scene file" begin
    pkg = dirname(@__DIR__)
    pairs = map(
        eachline(
            joinpath(
                pkg,
                "scenes",
                "v04-normal-eq.scene",
            ),
        ),
    ) do line
        k, v = split(line, " = "; limit = 2)
        return k => v
    end
    m = Dict(pairs)
    @test m["file"] == "src/fit.jl"
    src = readlines(joinpath(pkg, m["file"]))
    @test within(src)
    @test m["run"] == "main()"

    top = Meta.parseall(
        read(joinpath(pkg, m["file"]), String),
    )
    nodes = filter(x -> x isa LineNumberNode, top.args)
    s = [n.line for n in nodes]
    t = [
        parse.(Int, split(x, "-")) for
        x in split(m["ticks"], ",")
    ]
    @test 4 <= length(t) <= 6
    @test all(x -> x[1] <= x[2], t)
    @test all(
        i -> t[i][2] < t[i + 1][1],
        1:(length(t) - 1),
    )
    @test all(x -> x[1] in s, t)
    ends = vcat(s, length(src) + 1)
    @test all(x -> x[2] + 1 in ends, t)
    @test t[1][1] == 1
    @test t[end][2] == length(src)

    @testset "vimrc.demo ticks equal the manifest" begin
        rc = read(joinpath(pkg, "vimrc.demo"), String)
        calls = [
            parse(Int, c[1]) for c in eachmatch(
                r"<F\d+> <Cmd>call Tick\((\d+)\)",
                rc,
            )
        ]
        @test calls == first.(t)
    end

    @testset "can fail: a long scene file is caught" begin
        @test !within(fill("x", 26))
        @test !within(["x" ^ 57])
        @test !within(["x" * Char(92)])
        @test within(["x" ^ 56])
    end
end
