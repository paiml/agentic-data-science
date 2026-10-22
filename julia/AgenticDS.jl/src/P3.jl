"""
    read_split(path) -> Vector{String}

Read the fixed train/test split (one label per clean row).
"""
function read_split(path)
    return CSV.read(path, DataFrame; types = Dict(:row => Int, :set => String)).set
end

"""
    read_centroids(path) -> Matrix{Float64}

Read the fixed initial centroids (one row per cluster, columns in `NUMERIC_COLS` order).
"""
function read_centroids(path)
    df = CSV.read(path, DataFrame; types = Dict(:cluster => Int))
    return Matrix{Float64}(df[:, NUMERIC_COLS])
end

"""
    confusion(truth, pred, classes) -> Matrix{Int}

Confusion matrix with truth in rows and prediction in columns.
"""
function confusion(truth, pred, classes)
    return [sum((truth .== a) .& (pred .== b)) for a in classes, b in classes]
end

"""
    accuracy(truth, pred) -> Float64

Share of correct predictions.
"""
accuracy(truth, pred) = mean(truth .== pred)

struct Leaf
    label::Int
end

struct Split
    var::Int
    cut::Float64
    left::Union{Leaf,Split}
    right::Union{Leaf,Split}
end

const MINSPLIT = 20
const MINBUCKET = 7
const CP = 0.01
const MAXDEPTH = 30

gini_dev(counts) = (n = sum(counts); n - sum(abs2, counts) / n)

majority(counts) = argmax(counts)

function class_counts(y, rows, nclass)
    return [count(==(k), view(y, rows)) for k = 1:nclass]
end

# Best primary split of `rows`: highest drop in n*gini; earlier variable and lower cut win ties.
function best_split(X, y, rows, nclass, minbucket)
    parent = gini_dev(class_counts(y, rows, nclass))
    best = (; gain = 0.0, var = 0, cut = 0.0)
    for var in axes(X, 2)
        order = sort(rows; by = r -> X[r, var])
        xs = X[order, var]
        left = zeros(Int, nclass)
        total = class_counts(y, rows, nclass)
        for i = 1:(length(order) - 1)
            left[y[order[i]]] += 1
            xs[i] == xs[i + 1] && continue
            (i < minbucket || length(order) - i < minbucket) && continue
            gain = parent - gini_dev(left) - gini_dev(total .- left)
            if gain > best.gain
                best = (; gain, var, cut = (xs[i] + xs[i + 1]) / 2)
            end
        end
    end
    return best
end

# Grow below `rows`; returns `(node, errors)` where `errors` counts the training misclassifications
# of the subtree. A split is kept only if it removes at least `CP * root_err` errors (a per-node prune, not rpart's weakest-link rule).
function grow(X, y, rows, nclass, root_err, depth)
    counts = class_counts(y, rows, nclass)
    leaf = Leaf(majority(counts))
    leaf_err = length(rows) - maximum(counts)
    (length(rows) < MINSPLIT || depth >= MAXDEPTH || gini_dev(counts) == 0) &&
        return (leaf, leaf_err)
    best = best_split(X, y, rows, nclass, MINBUCKET)
    best.var == 0 && return (leaf, leaf_err)
    go_left = X[rows, best.var] .< best.cut
    left, left_err = grow(X, y, rows[go_left], nclass, root_err, depth + 1)
    right, right_err = grow(X, y, rows[.!go_left], nclass, root_err, depth + 1)
    leaf_err - (left_err + right_err) < CP * root_err && return (leaf, leaf_err)
    return (Split(best.var, best.cut, left, right), left_err + right_err)
end

"""
    fit_species_clf(train) -> NamedTuple

Fit a CART decision tree on `NUMERIC_COLS` with rpart's default parameters, matching rpart on the golden fixtures
(Gini splits, `minsplit` 20, `minbucket` 7, midpoint cuts; a split survives only if it removes at least `cp` 0.01 of the root misclassifications. This is a per-node prune, not rpart's weakest-link rule): `(; tree, classes)`.
"""
function fit_species_clf(train)
    classes = sort(unique(train.species))
    X = Matrix{Float64}(train[:, NUMERIC_COLS])
    y = [findfirst(==(s), classes) for s in train.species]
    counts = class_counts(y, 1:length(y), length(classes))
    tree, _ =
        grow(X, y, collect(1:length(y)), length(classes), length(y) - maximum(counts), 0)
    return (; tree, classes)
end

descend(node::Leaf, x) = node.label
descend(node::Split, x) = descend(x[node.var] < node.cut ? node.left : node.right, x)

"""
    predict_species_clf(fit, test) -> Vector{String}

Predict species names for the rows of `test`.
"""
function predict_species_clf(fit, test)
    X = Matrix{Float64}(test[:, NUMERIC_COLS])
    return [fit.classes[descend(fit.tree, view(X, i, :))] for i in axes(X, 1)]
end

"""
    kmeans_fixed(df, centroids; max_iter = 100) -> NamedTuple

Lloyd k-means on z-scored features from fixed initial centroids (raw units):
`(; cluster, objective)`.
"""
function kmeans_fixed(df, centroids; max_iter = 100)
    X = Matrix{Float64}(df[:, NUMERIC_COLS])
    centre = mean(X; dims = 1)
    spread = std(X; dims = 1)
    z = (X .- centre) ./ spread
    cen = (centroids .- centre) ./ spread
    cluster = zeros(Int, size(z, 1))
    for _ = 1:max_iter
        dist = [sum(abs2, z[i, :] .- cen[k, :]) for i in axes(z, 1), k in axes(cen, 1)]
        new_cluster = [argmin(dist[i, :]) for i in axes(dist, 1)]
        new_cluster == cluster && break
        cluster = new_cluster
        for k in axes(cen, 1)
            members = cluster .== k
            any(members) && (cen[k, :] = vec(mean(z[members, :]; dims = 1)))
        end
    end
    return (; cluster, objective = sum(abs2, z .- cen[cluster, :]))
end

"""
    p3_json(df, split, centroids) -> OrderedDict

P3 results in the golden JSON layout.
"""
function p3_json(df, split, centroids)
    fit = fit_species_clf(df[split .== "train", :])
    test = df[split .== "test", :]
    pred = predict_species_clf(fit, test)
    km = kmeans_fixed(df, centroids)
    return OrderedDict(
        "accuracy" => accuracy(test.species, pred),
        "confusion" =>
            [collect(r) for r in eachrow(confusion(test.species, pred, fit.classes))],
        "classes" => fit.classes,
        "kmeans" => OrderedDict(
            "objective" => km.objective,
            "cluster_sizes" => [count(==(k), km.cluster) for k in axes(centroids, 1)],
        ),
    )
end
