#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M2 video 10: what the gate proved: both P2 examples hold their contract
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
for e in c-m2-p2-ols c-m2-p2-cv; do Rscript "r/agenticds/inst/examples/$e/run.R" | grep '^contract:'; done
echo "contract: c-m2 wrap-up OK"
