const SCORES = 0:10
const COLORS = ("red", "white")
function read_wine(red, white)
    read(f) = CSV.read(f, DataFrame)
    return vcat(read(red), read(white))
end
function validate_wine(df)
    miss = any(c -> any(ismissing, c), eachcol(df))
    check(!miss, "wine data has missing values")
    q, c = df.quality, df.color
    check(all(in(SCORES), q), "quality outside 0..10")
    check(all(in(COLORS), c), "unknown color")
    return df
end
function main()
    df = read_wine(RED, WHITE)
    a, b = df.color[1], df.color[end]
    println("read $(nrow(df)) rows; first $a, last $b")
    ok = validate_wine(df) === df
    println("clean table passes: $ok")
    ok &= refuse_all(validate_wine, df)
    verdict(ok, "validate_wine refuses 3 bad tables")
end
