#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M1 video 3: let na_policy keep every row in a scratch copy; the p1 tests go red
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
# shellcheck source=../mutate.sh
source "$(dirname "$0")/../mutate.sh"
mutate p1.R 's/!is.na(.x)/TRUE/' p1
echo "contract: c-m1 a no-op NA policy is caught OK"
