#!/usr/bin/env bash
# D-M1 video 10: the full gate
# shellcheck source=../d-lib.sh
source "$(dirname "$0")/../d-lib.sh"
make gate
echo "contract: full ADS gate passes OK"
