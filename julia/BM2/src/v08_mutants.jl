leak(X, y, rows) = backslash(X, y)
nobias(X, y, rows) = [0.0; honest(X[:, 2:end], y, rows)]

function fails(df, folds, train)
    X1, X2 = designs(df)
    g, y = golden().cv_rmse, df.body_mass_g
    a = cv_oof(X1, y, folds, train)
    b = cv_oof(X2, y, folds, train)
    return !near(a, g.ols) + !near(b, g.species)
end

function main()
    df, folds = load(), read_folds()
    base = fails(df, folds, honest)
    a = fails(df, folds, leak)
    b = fails(df, mod.(folds, 3) .+ 1, honest)
    c = fails(df, folds, nobias)
    println("leak: $a of 2 checks fail")
    println("wrong folds: $b of 2 checks fail")
    println("no intercept: $c of 2 checks fail")
    verdict(base == 0 && min(a, b, c) > 0, "caught")
end
