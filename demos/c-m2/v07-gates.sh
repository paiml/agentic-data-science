#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M2 video 7: R gate and SHACL run locally
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
make gate-shacl
make gate-r
echo "contract: c-m2 gates green OK"
