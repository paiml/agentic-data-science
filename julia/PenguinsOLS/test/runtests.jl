using PenguinsOLS
using DataFrames
using GLM
using JET
using Test

const CSV_PATH =
    joinpath(@__DIR__, "..", "data", "penguins.csv")
# datasets/golden/p2.json (ads-julia-p2-v1): closed-form OLS,
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

    @testset "can fail: no intercept breaks the zero-sum residuals" begin
        nointercept = lm(
            @formula(
                body_mass_g ~ 0 + flipper_length_mm
            ),
            df,
        )
        @test abs(sum(residuals(nointercept))) > 1.0
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
