const WINE_FEATURES = [
    :fixed_acidity,
    :volatile_acidity,
    :citric_acid,
    :residual_sugar,
    :chlorides,
    :free_sulfur_dioxide,
    :total_sulfur_dioxide,
    :density,
    :pH,
    :sulphates,
    :alcohol,
]

"""
    read_wine(red, white) -> DataFrame

Read and bind the red and white Wine Quality tables (red rows first).
"""
function read_wine(red, white)
    types = Dict(:quality => Int, :color => String)
    return vcat(
        CSV.read(red, DataFrame; types, missingstring = "NA"),
        CSV.read(white, DataFrame; types, missingstring = "NA"),
    )
end

"""
    validate_wine(df) -> DataFrame

Throw on a missing value, a quality outside 0..10, or an unknown colour; return `df` unchanged otherwise.
"""
function validate_wine(df)
    any(ismissing, Matrix(df)) && throw(ArgumentError("wine data has missing values"))
    all(0 .<= df.quality .<= 10) || throw(ArgumentError("quality outside 0..10"))
    all(in(("red", "white")), df.color) || throw(ArgumentError("unknown color"))
    return df
end

"""
    split_wine(df) -> NamedTuple

Deterministic split: every fifth row is a test row: `(; train, test)`.
"""
function split_wine(df)
    is_test = (1:nrow(df)) .% 5 .== 0
    return (; train = df[.!is_test, :], test = df[is_test, :])
end

# Intercept, the eleven measurements and the `white` indicator (R's treatment coding of `color`).
function wine_design(df)
    return hcat(
        ones(nrow(df)),
        Matrix{Float64}(df[:, WINE_FEATURES]),
        Float64.(df.color .== "white"),
    )
end

"""
    pipeline_wine(red, white) -> OrderedDict

Validate, split, fit a linear quality model on the train rows and score it on the test rows,
in the golden JSON layout of `datasets/golden/p4.json`.
"""
function pipeline_wine(red, white)
    df = validate_wine(read_wine(red, white))
    s = split_wine(df)
    beta = wine_design(s.train) \ Float64.(s.train.quality)
    m = regression_metrics(Float64.(s.test.quality), wine_design(s.test) * beta)
    by_color = Dict(c => mean(df.quality[df.color .== c]) for c in ("red", "white"))
    return OrderedDict(
        "n_rows" => nrow(df),
        "n_train" => nrow(s.train),
        "n_test" => nrow(s.test),
        "rmse" => m.rmse,
        "r2" => m.r2,
        "mean_quality_by_color" =>
            OrderedDict("red" => by_color["red"], "white" => by_color["white"]),
    )
end

"""
    report_ttl(res, path)

Write the pipeline report as an `ads:Artifact` in Turtle.
"""
function report_ttl(res, path)
    open(path, "w") do io
        println(io, "@prefix ads: <https://paiml.com/ns/ads#> .")
        println(io, "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .")
        println(io)
        println(io, "<https://paiml.com/ns/ads#wine-report> a ads:Artifact ;")
        println(io, "  ads:schemaVersion \"1\" ;")
        println(io, "  ads:generatedBy \"AgenticDS.pipeline_wine\" ;")
        println(
            io,
            "  ads:rmse \"",
            Printf.@sprintf("%.10f", res["rmse"]),
            "\"^^xsd:decimal ;",
        )
        println(io, "  ads:rows \"", res["n_rows"], "\"^^xsd:integer .")
    end
    return path
end

"""
    aggregate_groupby(df) -> DataFrame

Mean quality and count per colour with DataFrames `groupby`, sorted by colour.
"""
function aggregate_groupby(df)
    out = combine(groupby(df, :color), :quality => mean => :mean_quality, nrow => :n)
    return sort(out, :color)
end

"""
    aggregate_loop(df) -> DataFrame

Mean quality and count per colour with a plain `Dict` loop, sorted by colour.
"""
function aggregate_loop(df)
    sums = Dict{String,Float64}()
    counts = Dict{String,Int}()
    for (c, q) in zip(df.color, df.quality)
        sums[c] = get(sums, c, 0.0) + q
        counts[c] = get(counts, c, 0) + 1
    end
    colors = sort!(collect(keys(sums)))
    return DataFrame(;
        color = colors,
        mean_quality = [sums[c] / counts[c] for c in colors],
        n = [counts[c] for c in colors],
    )
end

"""
    bench_wine(df) -> DataFrame

Median wall time in seconds of the two aggregations, measured with BenchmarkTools.
"""
function bench_wine(df)
    times = [
        median(BenchmarkTools.@benchmark($f($df); samples = 20, evals = 1)).time / 1e9
        for f in (aggregate_groupby, aggregate_loop)
    ]
    return DataFrame(; engine = ["groupby", "loop"], seconds = times)
end
