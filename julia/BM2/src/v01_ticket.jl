function fit_flipper(df)
    X = design(df[:, [:flipper_length_mm]])
    return backslash(X, df.body_mass_g)
end

function say(label, pair, d)
    a, c = round.(pair; digits = d)
    println("golden $label: $a flipper, $c species")
end

beats(g) = g.cv_rmse.species < g.cv_rmse.ols

function main()
    g = golden()
    b = fit_flipper(load())
    i, s = round3.(b)
    println("golden ols: intercept $i, slope $s")
    m, cv = g.metrics, g.cv_rmse
    say("r2", (m.ols.r2, m.species.r2), 4)
    say("cv_rmse", (cv.ols, cv.species), 3)
    ok = near(b[2], g.ols.slope; tol = 1e-8)
    verdict(ok && beats(g), "species beats flipper")
end
