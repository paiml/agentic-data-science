function wine_design(df)
    x = Matrix{Float64}(df[:, 1:11])
    white = Float64.(df.color .== "white")
    return hcat(ones(nrow(df)), x, white)
end
function score(y, pred)
    err = y .- pred
    r2 = 1 - sum(abs2, err) / sum(abs2, y .- mean(y))
    return (rmse = sqrt(mean(abs2, err)), r2 = r2)
end
function pipeline_wine(red, white)
    df = validate_wine(read_wine(red, white))
    s = split_wine(df)
    beta = lstsq(wine_design(s.train), s.train.quality)
    x = wine_design(s.test)
    m = score(s.test.quality, x * beta)
    rows, train, test = nrow.((df, s.train, s.test))
    return (; rows, train, test, m...)
end
function main()
    r, g = pipeline_wine(RED, WHITE), golden()
    a, b, c = r.rows, r.train, r.test
    println("n_rows $a, n_train $b, n_test $c")
    ok = compare("rmse", r.rmse, g.rmse)
    ok &= compare("r2  ", r.r2, g.r2)
    verdict(ok, "pipeline_wine matches golden")
end
