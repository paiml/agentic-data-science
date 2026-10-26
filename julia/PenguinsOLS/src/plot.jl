# Plumbing for the demo scene (not shown): plot and verdict.
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

function verdict(ok)
    printstyled("golden: $ok"; color = ok ? 83 : 203)
    return println()
end
