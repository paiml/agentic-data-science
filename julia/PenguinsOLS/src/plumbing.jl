"A 720 x 1080 figure with one labelled axis."
function canvas()
    fig = Figure(size = (720, 1080), fontsize = 26)
    ax = Axis(fig[1, 1]; xlabel = "flipper mm")
    ax.ylabel = "mass g"
    return fig, ax
end

"Add the legend and write the figure to `path`."
function finish(fig, ax, path)
    axislegend(ax; position = :lt, labelsize = 28)
    return save(path, fig; px_per_unit = 1)
end

"Print the verdict line, green when ok, red when not."
function verdict(ok, label)
    printstyled("$label: $ok"; color = ok ? 83 : 203)
    println()
    return ok
end
