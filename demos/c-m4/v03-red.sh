#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M4 video 3: move the test rows in a scratch copy; the p4 tests go red
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
# shellcheck source=../mutate.sh
source "$(dirname "$0")/../mutate.sh"
mutate p4.R 's/%% 5L == 0L/%% 5L == 1L/' p4
echo "contract: c-m4 a shifted split is caught OK"
