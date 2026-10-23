#!/usr/bin/env bash
# B-M2 video 8: mutants in a scratch copy, a leaking fold, a wrong fold assignment and a dropped intercept; the tests catch all three
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
# shellcheck source=../mutate.sh
source "$(dirname "$0")/../mutate.sh"
mutate P2.jl 's/df\[folds \.!= k, :\]/df/'
mutate P2.jl 's/return CSV.read(path, DataFrame; types = Dict(:row => Int, :fold => Int)).fold/return mod.(CSV.read(path, DataFrame; types = Dict(:row => Int, :fold => Int)).fold, 3) .+ 1/'
mutate P2.jl 's/return (; intercept = b\[1\], slope = b\[2\])/return (; intercept = 0.0, slope = b[2])/'
echo "contract: b-m2 a leaking fold, a wrong fold assignment and a dropped intercept are all caught OK"
