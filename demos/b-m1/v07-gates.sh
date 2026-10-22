#!/usr/bin/env bash
# B-M1 video 07-gates: SHACL and Julia gates run locally (coverage 100%, format clean)
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
make gate-shacl
make gate-julia 2>&1 | grep -E '^(coverage|format clean|examples OK|gate-julia OK|UNCOVERED)'
echo "contract: b-m1 gates green OK"
