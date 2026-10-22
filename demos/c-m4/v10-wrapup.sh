#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M4 video 10: wrap-up, both P4 contracts
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
for e in c-m4-p4-pipeline c-m4-p4-bench; do Rscript "r/agenticds/inst/examples/$e/run.R" | grep '^contract:'; done
echo "contract: c-m4 wrap-up OK"
