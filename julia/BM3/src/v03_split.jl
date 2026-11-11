gini(c) = (n = sum(c); n - sum(abs2, c) / n)
function best_cut(x, y; minbucket = 1)
    xs, ys = sort(x), y[sortperm(x)]
    tot = sizes(ys)
    best, cut = 0.0, NaN
    for i = minbucket:(length(xs) - minbucket)
        xs[i] == xs[i + 1] && continue
        left = sizes(ys[1:i])
        gain = gini(tot) - gini(left) - gini(tot - left)
        if gain > best
            best, cut = gain, (xs[i] + xs[i + 1]) / 2
        end
    end
    return best, cut
end
function toy_cuts()
    x, y = [1.0, 2, 3, 10, 11, 12], [1, 1, 1, 2, 2, 2]
    t = best_cut([1.0, 2.0, 3.0, 4.0], [1, 2, 1, 2])
    return best_cut(x, y), best_cut(x, 3 .- y), t
end
function main()
    a, b, t = toy_cuts()
    println("gain, cut: $a and $b, tie $t")
    verdict(a == b == (3.0, 6.5) && t[2] == 1.5)
end
