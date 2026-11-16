#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M1 video 8: swap sample sd for population sd in a scratch copy; the tests catch it
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
# shellcheck source=../mutate.sh
source "$(dirname "$0")/../mutate.sh"
mutate p1.R 's/sd = stats::sd/sd = function(x) sqrt(mean((x - mean(x))^2))/' p1
echo "contract: c-m1 a population sd is caught OK"
