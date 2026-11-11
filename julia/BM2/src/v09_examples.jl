function ols_example()
    df = load()
    b = backslash(designs(df)[1], df.body_mass_g)
    i, s = trim4.(b)
    println((intercept = i, slope = s))
    ok = near(b[2], golden().ols.slope; tol = 1e-8)
    return contract(ok)
end

cv_line(l, x) = println("cv_rmse ($l): ", trim4(x))

function cv_example()
    df, folds = load(), read_folds()
    X1, X2 = designs(df)
    y = df.body_mass_g
    println("coefs = ", trim4.(backslash(X2, y)))
    a, b = cv_oof(X1, y, folds), cv_oof(X2, y, folds)
    cv_line("ols", a)
    cv_line("species", b)
    return contract(near(b, golden().cv_rmse.species))
end

function main()
    verdict(ols_example() && cv_example(), "examples")
end
