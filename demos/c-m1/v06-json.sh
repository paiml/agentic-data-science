#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M1 video 6: the profile example prints its JSON and matches the golden
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript r/agenticds/inst/examples/c-m1-p1-profile/run.R | tail -n 22
Rscript r/agenticds/inst/examples/c-m1-p1-profile/run.R | grep -q '^contract: ads-r-p1 profile matches golden/p1.json OK$'
echo "contract: c-m1 profile JSON equals the golden OK"
