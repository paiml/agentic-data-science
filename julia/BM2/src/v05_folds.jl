rmse(y, p) = sqrt(mean((y .- p) .^ 2))
insample(X, y) = rmse(y, X * backslash(X, y))

function cv_rmse(X, y, folds)
    pred = similar(y)
    for k in sort(unique(folds))
        test = folds .== k
        b = backslash(X[.!test, :], y[.!test])
        pred[test] = X[test, :] * b
    end
    return rmse(y, pred)
end

function main()
    df = load()
    X1, X2 = designs(df)
    y, folds = df.body_mass_g, read_folds()
    println("fold sizes: ", fold_sizes(folds))
    println("in-sample rmse: ", round3(insample(X1, y)))
    cv = [cv_rmse(X, y, folds) for X in (X1, X2)]
    println("cv_rmse (flipper, species): ", round3.(cv))
    g = golden().cv_rmse
    ok = near(cv[1], g.ols) && near(cv[2], g.species)
    verdict(ok && insample(X1, y) < cv[1], "golden")
end
