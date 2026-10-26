#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M3 video 10: wrap-up, both P3 contracts
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
for e in c-m3-p3-tree c-m3-p3-kmeans; do Rscript "r/agenticds/inst/examples/$e/run.R" | grep '^contract:'; done
echo "contract: c-m3 wrap-up OK"
