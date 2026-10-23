#!/usr/bin/env bash
# B-M3 video 02-features: four numeric features and why k-means z-scores them
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
julia --project="$PKG" -e '
using AgenticDS, DataFrames, Statistics
d = na_policy(read_penguins("datasets/penguins/penguins.csv"))
X = Matrix{Float64}(d[:, NUMERIC_COLS])
centre = mean(X; dims = 1); spread = std(X; dims = 1)
z = (X .- centre) ./ spread
println(rpad("feature", 20), lpad("mean", 10), lpad("sd", 10), lpad("|z mean|", 10), lpad("z sd", 8))
for (j, c) in enumerate(NUMERIC_COLS)
    println(rpad(string(c), 20), lpad(round(centre[j]; digits = 2), 10), lpad(round(spread[j]; digits = 2), 10),
        lpad(round(abs(mean(z[:, j])); digits = 6), 10), lpad(round(std(z[:, j]); digits = 4), 8))
end
raw1 = abs2(X[1, 4] - X[2, 4]) / (abs2(X[1, 1] - X[2, 1]) + abs2(X[1, 2] - X[2, 2]) + abs2(X[1, 3] - X[2, 3]) + abs2(X[1, 4] - X[2, 4]))
println("raw squared distance of rows 1 and 2: body mass share ", round(raw1; digits = 4))
@assert size(X) == (342, 4) && raw1 > 0.98
@assert all(abs.(mean(z; dims = 1)) .< 1e-12) && all(isapprox.(std(z; dims = 1), 1; atol = 1e-12))
println("contract: b-m3 z-scoring gives every feature mean 0 and sd 1 OK")'
