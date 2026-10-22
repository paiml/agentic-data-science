#!/usr/bin/env bash
# B-M1 video 08-sd: swap sample sd for population sd in a scratch copy; the tests catch it
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
# shellcheck source=../mutate.sh
source "$(dirname "$0")/../mutate.sh"
mutate AgenticDS.jl 's/col => std =>/col => (x -> sqrt(mean((x .- mean(x)) .^ 2))) =>/'
echo "contract: b-m1 a population sd is caught OK"
