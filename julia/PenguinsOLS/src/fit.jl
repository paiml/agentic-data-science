const COLS = [:flipper_length_mm, :body_mass_g]
const FORM = @formula(body_mass_g ~ flipper_length_mm)
function load_penguins(path)
    df = CSV.read(path, DataFrame; missingstring = "NA")
    return dropmissing(df, COLS)
end
fit_ols(df) = lm(FORM, df)
function save_plot(df, model, path)
    fig = Figure(size = (720, 1080), fontsize = 26)
    ax = Axis(fig[1, 1]; xlabel = "flipper mm")
    ax.ylabel = "mass g"
    x, y = df.flipper_length_mm, df.body_mass_g
    scatter!(ax, x, y; markersize = 10, label = "data")
    yhat = predict(model)
    lines!(ax, x, yhat; linewidth = 5, label = "fit")
    axislegend(ax; position = :lt, labelsize = 28)
    return save(path, fig; px_per_unit = 1)
end

function main(path = "data/penguins.csv")
    df = load_penguins(path)
    model = fit_ols(df)
    i, s = round.(coef(model); digits = 2)
    println((rows = nrow(df), intercept = i, slope = s))
    save_plot(df, model, "plot.png")
    ok = (i, s) == (-5780.83, 49.69)
    printstyled("golden: $ok"; color = ok ? 83 : 203)
    println()
end
