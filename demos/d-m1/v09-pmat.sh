#!/usr/bin/env bash
# D-M1 video 9: pmat quality gate
# shellcheck source=../d-lib.sh
source "$(dirname "$0")/../d-lib.sh"
cd kotlin && pmat quality-gate -p . --checks complexity,satd,duplicates --fail-on-violation -q
echo "contract: pmat complexity, satd and duplicates gate passes OK"
