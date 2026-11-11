zscore(X) = (X .- mean(X; dims = 1)) ./ std(X; dims = 1)
function feature_table(X, z)
    head = ["mean", "sd", "|z mean|", "z sd"]
    table_row("feature", head)
    for (j, c) in enumerate(COLS)
        mu, sd = mean(X[:, j]), std(X[:, j])
        zm, zs = mean(z[:, j]), std(z[:, j])
        table_row(c, rnd.([mu, sd, abs(zm), zs]))
    end
end
function body_share(X)
    d = abs2.(X[1, :] - X[2, :])
    s = d[4] / sum(d)
    print("raw squared distance of rows 1 and 2: ")
    println("body mass share ", rnd(s, 4))
    return s
end
function main()
    X = task().X
    z = zscore(X)
    feature_table(X, z)
    share = body_share(X)
    verdict(standard(z) & (share > 0.98))
end
