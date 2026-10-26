# Plumbing for the BM4 scenes (never shown on camera): paths,
# the golden file, the verdict colours and the bad-table cases.
const ROOT =
    normpath(joinpath(@__DIR__, "..", "..", ".."))
const DATA = joinpath(ROOT, "datasets", "wine-quality")
const RED = joinpath(DATA, "winequality-red.csv")
const WHITE = joinpath(DATA, "winequality-white.csv")
const SUMS = joinpath(DATA, "SHA256SUMS")
const GOLD =
    joinpath(ROOT, "datasets", "golden", "p4.json")
const R_TTL = joinpath(
    ROOT,
    "datasets",
    "golden",
    "p4-artifact.ttl",
)
const CONTRACT =
    joinpath(ROOT, "contracts", "ads-julia-p4-v1.yaml")
const SHAPES = joinpath(
    ROOT,
    "ontology",
    "shapes",
    "artifact.shape.ttl",
)
const TTL_HEAD = [
    "@prefix ads: <https://paiml.com/ns/ads#> .",
    "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .",
    "",
    "<https://paiml.com/ns/ads#wine-report> a ads:Artifact ;",
]
# label, column, bad value, message the validator must give
const BAD = [
    (
        "missing value",
        :alcohol,
        missing,
        "ArgumentError: wine data has missing values",
    ),
    (
        "quality 11",
        :quality,
        11,
        "ArgumentError: quality outside 0..10",
    ),
    (
        "colour rose",
        :color,
        "rose",
        "ArgumentError: unknown color",
    ),
]

# The golden file in the shape pipeline_wine returns.
function golden()
    g = JSON3.read(read(GOLD, String))
    return (
        rows = g.n_rows,
        train = g.n_train,
        test = g.n_test,
        rmse = g.rmse,
        r2 = g.r2,
        means = g.mean_quality_by_color,
    )
end

# Least squares by QR (the operator is kept out of the shown code).
lstsq(X, y) = X \ y

check(ok, msg) = ok || throw(ArgumentError(msg))

# Floats are compared with a tolerance, never with ==.
near(a, b) = isapprox(a, b; atol = 1e-6)

# Nine decimals, the precision the golden file is shown at.
r9(x) = round(x; digits = 9)

# One line "label value (golden value)"; true when they agree.
function compare(label, got, want)
    println(
        label,
        " ",
        r9(got),
        " (golden ",
        r9(want),
        ")",
    )
    return near(got, want)
end

# Train and test rows of df, the test rows picked by a mask.
function by_mask(df, mask)
    return (train = df[.!mask, :], test = df[mask, :])
end

# A copy of df whose first row has `v` in column `col`.
function with(df, col, v)
    bad = allowmissing(df, col)
    bad[1, col] = v
    return bad
end

# The message a function gives when it refuses its input.
function refusal(f, x)
    try
        f(x)
    catch e
        return sprint(showerror, e)
    end
    return "accepted"
end

# Print each bad table's refusal; true when all three are right.
function refuse_all(f, df)
    ok = true
    for (label, col, v, want) in BAD
        msg = refusal(f, with(df, col, v))
        println(label, " -> ", msg)
        ok &= msg == want
    end
    return ok
end

# Final verdict line: green 83 when it holds, red 203 when not.
function verdict(ok, text)
    line =
        "contract: b-m4 " *
        text *
        (ok ? " OK" : " FAIL")
    printstyled(line; color = ok ? 83 : 203)
    println()
    return ok
end

# A red FAIL line.
function failed(name)
    printstyled("FAIL ", name; color = 203)
    println()
end

# A DataFrame printed without its summary and type rows.
function table(t)
    show(t; summary = false, eltypes = false)
    println()
end

# Both aggregates give the same colours, counts, means and golden.
function agree(a, b)
    g = golden()
    same = a.color == b.color && a.n == b.n
    m = (a.mean_quality, b.mean_quality)
    same &= isapprox(m...; atol = 1e-12)
    return same &&
           isapprox(m[1], [g.means.red, g.means.white])
end

# The lines a function writes to an io.
function captured(f)
    io = IOBuffer()
    f(io)
    return readlines(IOBuffer(take!(io)))
end

# A PASS or FAIL line for one claim.
function claim(ok, text)
    printstyled(
        ok ? "PASS " : "FAIL ";
        color = ok ? 83 : 203,
    )
    println(text)
end
