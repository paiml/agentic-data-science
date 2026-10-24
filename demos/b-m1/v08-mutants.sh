#!/usr/bin/env bash
# B-M1 video 8: two mutants in a scratch copy, an over-eager NA policy and a population sd; the tests catch both
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
# shellcheck source=../mutate.sh
source "$(dirname "$0")/../mutate.sh"
mutate AgenticDS.jl 's/dropmissing(df, NUMERIC_COLS)/dropmissing(df)/'
mutate AgenticDS.jl 's/col => std =>/col => (x -> sqrt(mean((x .- mean(x)) .^ 2))) =>/'
echo "contract: b-m1 an over-eager NA policy and a population sd are both caught OK"
