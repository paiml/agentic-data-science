#!/usr/bin/env bash
# B-M4 video 05-leak: a mutant fits on the test rows in a scratch copy; the tests kill it
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
# shellcheck source=../mutate.sh
source "$(dirname "$0")/../mutate.sh"
mutate P4.jl 's/beta = wine_design(s.train) \\ Float64.(s.train.quality)/beta = wine_design(s.test) \\ Float64.(s.test.quality)/'
echo "contract: b-m4 a fit on the test rows is caught by the tests OK"
