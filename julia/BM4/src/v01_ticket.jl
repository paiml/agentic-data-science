function verify(line)
    hash, file = split(line)
    path = joinpath(DATA, file)
    ok = bytes2hex(open(sha256, path)) == hash
    println(file, ": ", ok ? "OK" : "FAILED")
    return ok
end
rows(file) = nrow(CSV.read(file, DataFrame))
function show_head(path)
    for line in readlines(path)[1:2]
        println(first(line, 57))
    end
end
function main()
    sums = all([verify(l) for l in eachline(SUMS)])
    show_head(CONTRACT)
    r, w, g = rows(RED), rows(WHITE), golden()
    println("rows $(r + w) (red $r, white $w)")
    println("golden: $(g.rows)=$(g.train)+$(g.test)")
    ok = r + w == g.rows && g.train + g.test == r + w
    verdict(sums && ok, "ticket oracle fits the data")
end
