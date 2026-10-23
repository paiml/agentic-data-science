#!/usr/bin/env bash
# B-M4 video 03-split: a red-first check on a naive split, then split_wine every fifth row, in memory
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
julia --project="$PKG" -e '
using AgenticDS, DataFrames
d = read_wine("datasets/wine-quality/winequality-red.csv", "datasets/wine-quality/winequality-white.csv")
want(s) = s.test == d[5:5:nrow(d), :] && nrow(s.train) + nrow(s.test) == nrow(d)
naive(df) = (; train = df[1:(nrow(df) - nrow(df) ÷ 5), :], test = df[(nrow(df) - nrow(df) ÷ 5 + 1):end, :])
println("RED: naive last-fifth split meets the test? ", want(naive(d)))
@assert !want(naive(d))
s = split_wine(d)
println("GREEN: split_wine train ", nrow(s.train), ", test ", nrow(s.test), ", meets the test? ", want(s))
@assert want(s) && nrow(s.train) == 5198 && nrow(s.test) == 1299
@assert s.train[5, :] == d[6, :]
println("contract: b-m4 split_wine takes every fifth row as test, 5198 train and 1299 test OK")'
