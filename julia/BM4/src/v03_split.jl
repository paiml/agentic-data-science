function want(df, s)
    test = df[5:5:nrow(df), :]
    total = nrow(s.train) + nrow(s.test)
    return isequal(s.test, test) && total == nrow(df)
end
function naive(df)
    n = nrow(df)
    return by_mask(df, (1:n) .> n - div(n, 5))
end
function split_wine(df)
    return by_mask(df, (1:nrow(df)) .% 5 .== 0)
end
function main()
    df = read_wine(RED, WHITE)
    s = split_wine(df)
    red, green = want(df, naive(df)), want(df, s)
    println("RED: naive split meets the test? $red")
    a, b = nrow(s.train), nrow(s.test)
    println("GREEN: train $a, test $b, passes? $green")
    fifth = isequal(s.train[5, :], df[6, :])
    verdict(
        !red && green && fifth,
        "every fifth row is test",
    )
end
