const PKG = dirname(@__DIR__)
const DATA = joinpath(@__DIR__, "..", "data")
const NUM = [
    :bill_length_mm,
    :bill_depth_mm,
    :flipper_length_mm,
    :body_mass_g,
]

"Clean penguin rows: NA dropped on the numeric columns."
function load()
    path = joinpath(DATA, "penguins.csv")
    df = CSV.read(path, DataFrame; missingstring = "NA")
    df = dropmissing(df, NUM)
    return transform(df, NUM .=> ByRow(Float64) .=> NUM)
end

"The P2 golden file as a JSON3 object."
golden() = JSON3.read(read(joinpath(DATA, "p2.json")))

"Fold id of every clean row, read from the fixture file."
function read_folds()
    return CSV.read(
        joinpath(DATA, "folds.csv"),
        DataFrame,
    ).fold
end

"The species design as a table (Adelie is the baseline)."
function species_table(df)
    return DataFrame(
        flipper_length_mm = df.flipper_length_mm,
        speciesChinstrap = Float64.(
            df.species .== "Chinstrap",
        ),
        speciesGentoo = Float64.(
            df.species .== "Gentoo",
        ),
    )
end

"Design matrix with a leading column of ones."
design(t) = hcat(ones(nrow(t)), Matrix(t))

"The least-squares operator, kept out of the shown files."
backslash(X, y) = X \ y

"Fit on the training rows (all rows but `rows`)."
honest(X, y, rows) = backslash(X[rows, :], y[rows])

"Out-of-fold RMSE with fixed folds."
function cv_oof(X, y, folds, train = honest)
    pred = similar(y)
    for k in sort(unique(folds))
        test = folds .== k
        pred[test] = X[test, :] * train(X, y, .!test)
    end
    return sqrt(mean((y .- pred) .^ 2))
end

"The flipper-only and the species design matrices."
function designs(df)
    return design(df[:, [:flipper_length_mm]]),
    design(species_table(df))
end

round3(x) = round(x; digits = 3)
trim4(x) = trunc(x; digits = 4)

"Print the contract line of the P2 examples."
function contract(ok)
    println(
        "contract: ads-julia-p2-v1 ",
        ok ? "OK" : "FAIL",
    )
    return ok
end

"Absolute-tolerance comparison, never == on floats."
near(a, b; tol = 1e-6) = isapprox(a, b; atol = tol)

"Print the verdict line, green when ok, red when not."
function verdict(ok, label)
    printstyled("$label: $ok"; color = ok ? 83 : 203)
    println()
    return ok
end

"Five fold sizes, counted from the fold ids."
fold_sizes(folds) = [count(==(k), folds) for k = 1:5]

"Run f(m); the error it throws, or its value."
function red(f, m)
    return try
        invokelatest(f, m)
    catch err
        err
    end
end

"Fitted MLJ parameters as name => value, intercept first."
function named_params(p)
    rest = [String(n) => c for (n, c) in p.coefs]
    return ["(Intercept)" => p.intercept; rest]
end

"Same names, same values within tolerance, by name."
function same_params(got, golden)
    want = Dict(String(k) => v for (k, v) in golden)
    return sort(first.(got)) ==
           sort(collect(keys(want))) &&
           all(near(c, want[n]) for (n, c) in got)
end
