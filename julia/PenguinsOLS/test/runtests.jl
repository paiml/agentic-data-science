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

# --- scene layout: the manifest, the shown file and vimrc.demo ---

function scene_keys(path)
    pairs = split.(readlines(path), " = "; limit = 2)
    return Dict(
        String(k) => String(v) for (k, v) in pairs
    )
end

function toplevel_count(text)
    ex = Meta.parseall(text)
    bad = any(
        a ->
            a isa Expr &&
            a.head in (:error, :incomplete),
        ex.args,
    )
    return bad ? -1 :
           count(a -> !(a isa LineNumberNode), ex.args)
end

@testset "scene layout" begin
    root = joinpath(@__DIR__, "..")
    keys = scene_keys(
        joinpath(root, "scenes", "p2-demo.scene"),
    )
    text = read(joinpath(root, keys["file"]), String)
    lines = split(chomp(text), "\n")
    spans = [
        Tuple(parse.(Int, split(p, "-"))) for
        p in split(keys["ticks"], ",")
    ]
    @test length(lines) <= 25
    @test all(length.(lines) .<= 56)
    @test !occursin('\\', text)
    @test 4 <= length(spans) <= 6
    @test all(lo <= hi for (lo, hi) in spans)
    @test all(
        spans[i][1] > spans[i - 1][2] for
        i = 2:length(spans)
    )
    @test spans[end][2] <= length(lines)
    covered = falses(length(lines))
    for (lo, hi) in spans
        covered[lo:hi] .= true
    end
    @test all(
        l ->
            isempty(strip(l)) ||
            startswith(strip(l), "#"),
        lines[.!covered],
    )
    counts = [
        toplevel_count(join(lines[lo:hi], "\n")) for
        (lo, hi) in spans
    ]
    @test all(counts .>= 1)
    @test sum(counts) == toplevel_count(text)
    @testset "vimrc.demo ticks are the manifest span starts" begin
        vim = read(joinpath(root, "vimrc.demo"), String)
        ticks = [
            parse(Int, m[1]) for m in eachmatch(
                r"<Cmd>call Tick\((\d+)\)<CR>",
                vim,
            )
        ]
        @test ticks == first.(spans)
        @test ticks != reverse(ticks)
    end
    @testset "can fail: an over-long shown file is rejected" begin
        long = join(fill("x = 1", 26), "\n")
        @test !(length(split(long, "\n")) <= 25)
        @test !(length("x"^57) <= 56)
        @test toplevel_count("function f(") == -1
    end
end
