# Tree plumbing for v04, v05 and later examples: node types,
# settings, the split search and printing. The growing loop
# (V04.grow) and the cut (V03.best_cut) are example files.
struct Leaf
    label::Int
end
struct Split
    var::Int
    cut::Float64
    left::Union{Leaf,Split}
    right::Union{Leaf,Split}
end

# rpart defaults: minsplit 20, minbucket 7, cp 0.01
const MINSPLIT = 20
const MINBUCKET = 7
const CP = 0.01

# Best primary split of `rows`: the largest drop in n*gini;
# the earlier column wins a tie.
function best_split(X, y, rows)
    best = (gain = 0.0, var = 0, cut = 0.0)
    for v in axes(X, 2)
        x = X[rows, v]
        gain, cut = V03.best_cut(
            x,
            y[rows];
            minbucket = MINBUCKET,
        )
        gain > best.gain &&
            (best = (; gain, var = v, cut))
    end
    return best
end

function fit_tree(t = task())
    rows = findall(t.train)
    root = length(rows) - maximum(V04.counts(t.y, rows))
    return first(V04.grow(t.X, t.y, rows, root))
end

descend(n::Leaf, x) = n.label
function descend(n::Split, x)
    return descend(
        x[n.var] < n.cut ? n.left : n.right,
        x,
    )
end
function predict(tree, X)
    return [
        descend(tree, view(X, i, :)) for i in axes(X, 1)
    ]
end

function score(tree, t = task())
    pred = predict(tree, t.X[t.test, :])
    return sum(pred .== t.y[t.test]), sum(t.test)
end

# ((column, cut), ...) for every split, left before right
outline(::Leaf) = ()
function outline(n::Split)
    return (
        (n.var, n.cut),
        outline(n.left)...,
        outline(n.right)...,
    )
end

label(n::Leaf) = GOLD.classes[n.label]
tag(n::Leaf) = ": " * label(n)
tag(n::Split) = ""
show_tree(n::Leaf, ind = "") = println(ind, label(n))
function show_tree(n::Split, ind = "")
    println(ind, COLS[n.var], " < ", n.cut, tag(n.left))
    n.left isa Split && show_tree(n.left, ind * "  ")
    println(ind, "else", tag(n.right))
    n.right isa Split && show_tree(n.right, ind * "  ")
    return nothing
end

# Features z-scored once, and the fixed start centres in the
# same units (a vector of rows).
function scaled()
    X = task().X
    m, s = mean(X; dims = 1), std(X; dims = 1)
    C = (centroids() .- m) ./ s
    return (X .- m) ./ s,
    [collect(r) for r in eachrow(C)]
end

sq(a, b) = sum(abs2, a - b)

settings() = "minsplit $MINSPLIT, minbucket $MINBUCKET, cp $CP"

# The two cuts the golden tree makes first.
const SHAPE = ((3, 207.5), (1, 43.35))
