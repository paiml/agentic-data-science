const P2 = JSON3.read(read(joinpath(ROOT, "datasets", "golden", "p2.json"), String))
const FOLDS_PATH = joinpath(ROOT, "datasets", "fixtures", "folds.csv")

@testset "AgenticDS P2" begin
    d = na_policy(read_penguins(CSV_PATH))
    folds = read_folds(FOLDS_PATH)

    @testset "read_folds" begin
        @test length(folds) == 342
        @test CSV.read(FOLDS_PATH, DataFrame).row == 1:342
        @test sort(unique(folds)) == 1:5
    end

    @testset "ols_closed_form matches golden" begin
        b = ols_closed_form(d.flipper_length_mm, d.body_mass_g)
        @test isapprox(b.intercept, P2.ols.intercept; atol = 1e-8)
        @test isapprox(b.slope, P2.ols.slope; atol = 1e-8)
    end

    @testset "fit_species (MLJ LinearRegressor) matches golden" begin
        sp = fit_species(d)
        @test collect(keys(sp)) ==
              ["(Intercept)", "flipper_length_mm", "speciesChinstrap", "speciesGentoo"]
        for k in keys(sp)
            @test isapprox(sp[k], P2.species_model[Symbol(k)]; atol = 1e-8)
        end
    end

    @testset "regression_metrics" begin
        m = regression_metrics([1.0, 2.0, 3.0], [1.0, 2.0, 4.0])
        @test isapprox(m.rmse, sqrt(1 / 3); atol = 1e-12)
        @test isapprox(m.r2, 1 - 1 / 2; atol = 1e-12)
        b = ols_closed_form(d.flipper_length_mm, d.body_mass_g)
        fit = b.intercept .+ b.slope .* d.flipper_length_mm
        g = regression_metrics(d.body_mass_g, fit)
        @test isapprox(g.rmse, P2.metrics.ols.rmse; atol = 1e-6)
        @test isapprox(g.r2, P2.metrics.ols.r2; atol = 1e-6)
        sg = regression_metrics(d.body_mass_g, predict_species(d, d))
        @test isapprox(sg.rmse, P2.metrics.species.rmse; atol = 1e-6)
        @test isapprox(sg.r2, P2.metrics.species.r2; atol = 1e-6)
    end

    @testset "cv_rmse matches golden and an independent per-fold oracle" begin
        @test isapprox(cv_rmse(d, folds, false), P2.cv_rmse.ols; atol = 1e-6)
        @test isapprox(cv_rmse(d, folds, true), P2.cv_rmse.species; atol = 1e-6)
        # oracle: per-fold normal equations written out, no shared code with cv_rmse
        sse = 0.0
        for k = 1:5
            tr = d[folds .!= k, :]
            te = d[folds .== k, :]
            x, y = tr.flipper_length_mm, tr.body_mass_g
            slope =
                sum((x .- sum(x) / length(x)) .* (y .- sum(y) / length(y))) /
                sum((x .- sum(x) / length(x)) .^ 2)
            icpt = sum(y) / length(y) - slope * sum(x) / length(x)
            sse += sum((te.body_mass_g .- (icpt .+ slope .* te.flipper_length_mm)) .^ 2)
        end
        @test isapprox(sqrt(sse / nrow(d)), P2.cv_rmse.ols; atol = 1e-6)
        # leakage can fail: predicting each fold with a model that saw it differs
        @test !isapprox(
            regression_metrics(
                d.body_mass_g,
                (
                    b = ols_closed_form(d.flipper_length_mm, d.body_mass_g);
                    b.intercept .+ b.slope .* d.flipper_length_mm
                ),
            ).rmse,
            P2.cv_rmse.ols;
            atol = 1e-6,
        )
    end

    @testset "p2_json round-trips to golden layout" begin
        out = JSON3.read(p2_json(d, folds))
        @test isapprox(out.ols.slope, P2.ols.slope; atol = 1e-8)
        @test isapprox(
            out.species_model.speciesGentoo,
            P2.species_model.speciesGentoo;
            atol = 1e-8,
        )
        @test isapprox(out.metrics.species.r2, P2.metrics.species.r2; atol = 1e-6)
        @test isapprox(out.cv_rmse.species, P2.cv_rmse.species; atol = 1e-6)
    end
end
