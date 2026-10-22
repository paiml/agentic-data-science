const P4 = JSON3.read(read(joinpath(ROOT, "datasets", "golden", "p4.json"), String))
const WINE_DIR = joinpath(ROOT, "datasets", "wine-quality")
const RED = joinpath(WINE_DIR, "winequality-red.csv")
const WHITE = joinpath(WINE_DIR, "winequality-white.csv")

@testset "AgenticDS P4" begin
    wine = read_wine(RED, WHITE)

    @testset "read_wine" begin
        @test nrow(wine) == 6497
        @test wine.color[1] == "red" && wine.color[end] == "white"
        @test count(==("red"), wine.color) == 1599
        @test eltype(wine.quality) == Int
    end

    @testset "validate_wine" begin
        @test validate_wine(wine) === wine
        missing_row = copy(wine; copycols = true)
        allowmissing!(missing_row, :alcohol)
        missing_row.alcohol[3] = missing
        @test_throws ArgumentError("wine data has missing values") validate_wine(
            missing_row,
        )
        high = copy(wine)
        high.quality[2] = 11
        @test_throws ArgumentError("quality outside 0..10") validate_wine(high)
        low = copy(wine)
        low.quality[2] = -1
        @test_throws ArgumentError("quality outside 0..10") validate_wine(low)
        rose = copy(wine)
        rose.color[2] = "rose"
        @test_throws ArgumentError("unknown color") validate_wine(rose)
    end

    @testset "split_wine" begin
        s = split_wine(wine)
        @test nrow(s.train) == P4.n_train && nrow(s.test) == P4.n_test
        @test s.test == wine[5:5:nrow(wine), :]
        @test nrow(s.train) + nrow(s.test) == nrow(wine)
        @test s.train[5, :] == wine[6, :]
    end

    @testset "pipeline_wine" begin
        res = pipeline_wine(RED, WHITE)
        @test res["n_rows"] == P4.n_rows
        @test res["n_train"] == P4.n_train
        @test res["n_test"] == P4.n_test
        @test isapprox(res["rmse"], P4.rmse; atol = 1e-6)
        @test isapprox(res["r2"], P4.r2; atol = 1e-6)
        @test isapprox(
            res["mean_quality_by_color"]["red"],
            P4.mean_quality_by_color.red;
            atol = 1e-6,
        )
        @test isapprox(
            res["mean_quality_by_color"]["white"],
            P4.mean_quality_by_color.white;
            atol = 1e-6,
        )
        @test collect(keys(res)) ==
              ["n_rows", "n_train", "n_test", "rmse", "r2", "mean_quality_by_color"]
        # the model is fitted on train rows only: its train RMSE is not the golden test RMSE
        s = split_wine(wine)
        beta = AgenticDS.wine_design(s.train) \ Float64.(s.train.quality)
        train_rmse = regression_metrics(
            Float64.(s.train.quality),
            AgenticDS.wine_design(s.train) * beta,
        ).rmse
        @test abs(train_rmse - res["rmse"]) > 1e-3
    end

    @testset "report_ttl" begin
        mktempdir() do dir
            path = report_ttl(pipeline_wine(RED, WHITE), joinpath(dir, "report.ttl"))
            golden = split(
                read(joinpath(ROOT, "datasets", "golden", "p4-artifact.ttl"), String),
                '\n',
            )
            lines = split(read(path, String), '\n')
            # identical to the R artifact except the generator name
            @test filter(!contains("generatedBy"), lines) ==
                  filter(!contains("generatedBy"), golden)
            text = read(path, String)
            @test occursin("a ads:Artifact", text)
            @test occursin("ads:rows \"6497\"^^xsd:integer", text)
            @test occursin("ads:generatedBy \"AgenticDS.pipeline_wine\"", text)
        end
    end

    @testset "aggregations and bench" begin
        a = aggregate_groupby(wine)
        b = aggregate_loop(wine)
        @test a.color == ["red", "white"] && b.color == a.color
        @test a.n == [1599, 4898] && b.n == a.n
        @test isapprox(a.mean_quality, b.mean_quality; atol = 1e-12)
        @test isapprox(a.mean_quality[1], P4.mean_quality_by_color.red; atol = 1e-6)
        t = bench_wine(wine)
        @test t.engine == ["groupby", "loop"]
        @test all(t.seconds .> 0)
    end
end
