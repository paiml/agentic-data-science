module Anscombe

using CairoMakie

export load_quartet, ols, correlation, report, save_plot, main

"""
    load_quartet(path)

Read the sha256-pinned `data/anscombe.csv` (columns `set,x,y`) into
four `(x, y)` vectors, in set order 1 to 4.
"""
function load_quartet(path)
    rows = split.(readlines(path)[2:end], ",")
    return [
        (
            [parse(Float64, r[2]) for r in rows if r[1] == string(k)],
            [parse(Float64, r[3]) for r in rows if r[1] == string(k)],
        ) for k = 1:4
    ]
end

"Closed-form least squares: returns `(intercept, slope)`."
function ols(x, y)
    mx = sum(x) / length(x)
    my = sum(y) / length(y)
    slope = sum((x .- mx) .* (y .- my)) / sum((x .- mx) .^ 2)
    return (my - slope * mx, slope)
end

"Pearson correlation of `x` and `y`."
function correlation(x, y)
    mx = sum(x) / length(x)
    my = sum(y) / length(y)
    sxy = sum((x .- mx) .* (y .- my))
    return sxy / sqrt(sum((x .- mx) .^ 2) * sum((y .- my) .^ 2))
end

"One printed line per set: n, intercept, slope, r (two decimals)."
function report(quartet)
    lines = String[]
    for (k, (x, y)) in enumerate(quartet)
        a, b = round.(ols(x, y); digits = 2)
        r = round(correlation(x, y); digits = 3)
        push!(lines, "set $k: n=$(length(x)) intercept=$a slope=$b r=$r")
    end
    return lines
end

"Write the four-panel scatter and fit-line plot as SVG to `path`."
function save_plot(quartet, path)
    fig = Figure(size = (1920, 1080), fontsize = 28)
    for (k, (x, y)) in enumerate(quartet)
        ax = Axis(
            fig[(k-1)÷2+1, (k-1)%2+1];
            title = "Set $k",
            xlabel = "x",
            ylabel = "y",
            limits = (2, 20, 2, 14),
        )
        scatter!(ax, x, y; markersize = 14)
        a, b = ols(x, y)
        lines!(ax, [4.0, 19.0], [a + 4b, a + 19b]; linewidth = 4)
    end
    save(path, fig)
    return path
end

"Print the report, write `plot.svg` into `outdir`."
function main(data = "data/anscombe.csv", outdir = ".")
    quartet = load_quartet(data)
    foreach(println, report(quartet))
    save_plot(quartet, joinpath(outdir, "plot.svg"))
    return nothing
end

end
