"""
    read_folds(path) -> Vector{Int}

Read the fixed fold assignment (one fold id per clean row).
"""
function read_folds(path)
    return CSV.read(path, DataFrame; types = Dict(:row => Int, :fold => Int)).fold
end

"""
    ols_closed_form(x, y) -> NamedTuple

Simple OLS by the normal equations, solved with `\\`: `(; intercept, slope)`.
"""
function ols_closed_form(x, y)
    design = [ones(length(x)) x]
    b = design \ y
    return (; intercept = b[1], slope = b[2])
end

"""
    regression_metrics(y, yhat) -> NamedTuple

RMSE and R squared of predictions: `(; rmse, r2)`.
"""
function regression_metrics(y, yhat)
    sse = sum((y .- yhat) .^ 2)
    return (; rmse = sqrt(sse / length(y)), r2 = 1 - sse / sum((y .- mean(y)) .^ 2))
end

function species_design(df)
    return DataFrame(;
        flipper_length_mm = Float64.(df.flipper_length_mm),
        speciesChinstrap = Float64.(df.species .== "Chinstrap"),
        speciesGentoo = Float64.(df.species .== "Gentoo"),
    )
end

function species_machine(df)
    model = MLJLinearModels.LinearRegressor()
    return MLJBase.machine(model, species_design(df), Float64.(df.body_mass_g)) |>
           MLJBase.fit!
end

"""
    fit_species(df) -> OrderedDict

Fit body mass on flipper length and species with MLJ `LinearRegressor`; coefficients are
named as R's `lm` names them.
"""
function fit_species(df)
    fp = MLJBase.fitted_params(species_machine(df))
    out = OrderedDict{String,Float64}("(Intercept)" => fp.intercept)
    for (name, value) in fp.coefs
        out[String(name)] = value
    end
    return out
end

function predict_species(train, test)
    return MLJBase.predict(species_machine(train), species_design(test))
end

function predict_ols(train, test)
    b = ols_closed_form(train.flipper_length_mm, train.body_mass_g)
    return b.intercept .+ b.slope .* test.flipper_length_mm
end

"""
    cv_rmse(df, folds, with_species) -> Float64

Pooled out-of-fold RMSE over a fixed fold assignment (each fold predicted by a model fitted
without it).
"""
function cv_rmse(df, folds, with_species)
    predictor = with_species ? predict_species : predict_ols
    pred = zeros(nrow(df))
    for k in sort(unique(folds))
        pred[folds .== k] = predictor(df[folds .!= k, :], df[folds .== k, :])
    end
    return regression_metrics(df.body_mass_g, pred).rmse
end

"""
    p2_json(df, folds) -> String

Serialise P2 results to the golden JSON layout (`datasets/golden/p2.json`).
"""
function p2_json(df, folds)
    b = ols_closed_form(df.flipper_length_mm, df.body_mass_g)
    ols_fit = b.intercept .+ b.slope .* df.flipper_length_mm
    m_ols = regression_metrics(df.body_mass_g, ols_fit)
    m_sp = regression_metrics(df.body_mass_g, predict_species(df, df))
    return JSON3.write(
        OrderedDict(
            "ols" => OrderedDict("intercept" => b.intercept, "slope" => b.slope),
            "species_model" => fit_species(df),
            "metrics" => OrderedDict(
                "ols" => OrderedDict("rmse" => m_ols.rmse, "r2" => m_ols.r2),
                "species" => OrderedDict("rmse" => m_sp.rmse, "r2" => m_sp.r2),
            ),
            "cv_rmse" => OrderedDict(
                "ols" => cv_rmse(df, folds, false),
                "species" => cv_rmse(df, folds, true),
            ),
        ),
    )
end
