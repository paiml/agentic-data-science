centre(A, o) = isempty(A) ? o : vec(mean(A; dims = 1))
function step(z, c)
    d = [sq(a, b) for a in eachrow(z), b in c]
    lab = [argmin(r) for r in eachrow(d)]
    c = [centre(z[lab .== k, :], c[k]) for k = 1:3]
    return lab, c
end
objective(z, c, lab) =
    sum(sq(z[i, :], c[l]) for (i, l) in enumerate(lab))
function lloyd(z, c; iters = 100)
    lab = zeros(Int, size(z, 1))
    for _ = 1:iters
        new, c = step(z, c)
        new == lab && break
        lab = new
    end
    return lab, objective(z, c, lab)
end
function main()
    z, c = scaled()
    lab, obj = lloyd(z, c)
    a, b = rnd.((lloyd(z, c; iters = 1)[2], obj), 4)
    scores(a, b, lab)
    verdict(kmeans_golden(obj, lab))
end
