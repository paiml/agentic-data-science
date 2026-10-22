#!/usr/bin/env bash
# B-M1 video 03-red: let the NA policy drop every row with a missing value in a scratch copy; the tests go red
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
# shellcheck source=../mutate.sh
source "$(dirname "$0")/../mutate.sh"
mutate AgenticDS.jl 's/dropmissing(df, NUMERIC_COLS)/dropmissing(df)/'
echo "contract: b-m1 an over-eager NA policy is caught OK"
