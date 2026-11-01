#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M1 video 10: wrap-up, both P1 contracts
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
for e in c-m1-p1 c-m1-p1-profile; do Rscript "r/agenticds/inst/examples/$e/run.R" | grep '^contract:'; done
echo "contract: c-m1 wrap-up OK"
