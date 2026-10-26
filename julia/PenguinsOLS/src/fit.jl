const COLS = [:flipper_length_mm, :body_mass_g]
const FORM = @formula(body_mass_g ~ flipper_length_mm)
function load_penguins(path)
    df = CSV.read(path, DataFrame; missingstring = "NA")
    return dropmissing(df, COLS)
end
fit_ols(df) = lm(FORM, df)

function main(path = "data/penguins.csv")
    df = load_penguins(path)
    model = fit_ols(df)
    i, s = round.(coef(model); digits = 2)
    println((rows = nrow(df), intercept = i, slope = s))
    save_plot(df, model, "plot.png")
    verdict((i, s) == (-5780.83, 49.69))
end
