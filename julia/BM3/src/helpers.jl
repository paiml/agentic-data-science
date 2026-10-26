# Plumbing for the BM3 scenes: paths, data, golden values.
# The scene files (src/vNN_*.jl) are the code shown on camera.
const ROOT = pkgdir(BM3)
const COLS = [
    :bill_length_mm,
    :bill_depth_mm,
    :flipper_length_mm,
    :body_mass_g,
]
# datasets/penguins/SHA256SUMS
const SHA_PENGUINS = "f204db2c753b0937caac3cb35258562c14f073e4bbc76be24b4c51ce22767a93"
# datasets/golden/p3.json (ads-r-p3-v1)
const GOLD = (
    accuracy = 0.976470588235294,
    confusion = [37 0 0; 0 16 1; 0 1 30],
    classes = ["Adelie", "Chinstrap", "Gentoo"],
    objective = 378.293614632478,
    sizes = [133, 123, 86],
)

datapath(file) = joinpath(ROOT, "data", file)

function checksum_ok()
    bytes = read(datapath("penguins.csv"))
    return bytes2hex(sha256(bytes)) == SHA_PENGUINS
end

function read_csv(file)
    return CSV.read(
        datapath(file),
        DataFrame;
        missingstring = "NA",
        stringtype = String,
    )
end

# Rows with a value in all four measurements (342 of 344).
function penguins()
    df = dropmissing(read_csv("penguins.csv"), COLS)
    return disallowmissing(df, COLS)
end

# Features, class index, and the fixed train/test split.
function task()
    df = penguins()
    set = read_csv("split.csv").set
    y = [
        findfirst(==(s), GOLD.classes) for
        s in df.species
    ]
    return (
        X = Matrix{Float64}(df[:, COLS]),
        y = y,
        train = set .== "train",
        test = set .== "test",
    )
end

function centroids()
    return Matrix{Float64}(
        read_csv("centroids.csv")[:, COLS],
    )
end

# Final line of every scene: green when the check holds.
function verdict(ok, word = "golden")
    printstyled("$word: $ok"; color = ok ? 83 : 203)
    return println()
end

function table_row(name, vals, w = 9)
    return println(rpad(name, 18), join(lpad.(vals, w)))
end

rnd(x, digits = 2) = round(x; digits)

wide_row(name, vals) = table_row(name, vals, 11)

# True when every column of z has mean 0 and sd 1.
function standard(z)
    flat = all(abs.(mean(z; dims = 1)) .< 1e-12)
    return flat &
           all(abs.(std(z; dims = 1) .- 1) .< 1e-12)
end

sizes(lab) = [count(==(k), lab) for k = 1:3]

function scores(a, b, lab)
    print("objective $a -> $b, ")
    println("golden $(rnd(GOLD.objective, 4))")
    return println(
        "sizes $(sizes(lab)), golden $(GOLD.sizes)",
    )
end

function hit_line(name, hit)
    println(rpad(name, 28), hit ? "caught" : "SURVIVED")
    return hit
end

function contract(ok)
    println(
        "contract: ads-r-p3-v1 ",
        ok ? "OK" : "FAILED",
    )
    return ok
end

function kmeans_golden(obj, lab)
    return obj ≈ GOLD.objective &&
           sizes(lab) == GOLD.sizes
end
