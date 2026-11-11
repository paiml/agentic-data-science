function aggregate_groupby(df)
    by = :quality => mean => :mean_quality
    return combine(groupby(df, :color), by, nrow => :n)
end
function aggregate_loop(df)
    rows = map(sort(unique(df.color))) do color
        q = df.quality[df.color .== color]
        (; color, mean_quality = mean(q), n = length(q))
    end
    return DataFrame(rows)
end
function bench_wine(df)
    fs = (aggregate_groupby, aggregate_loop)
    return [@belapsed($f($df); samples = 5) for f in fs]
end
function main()
    df = read_wine(RED, WHITE)
    a, b = aggregate_groupby(df), aggregate_loop(df)
    foreach(table, (a, b))
    pos = all(>(0), bench_wine(df))
    println("bench_wine: groupby, loop; positive: $pos")
    verdict(agree(a, b) && pos, "engines agree first")
end
