#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M4 video 7: SHACL and R gates run locally
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
make gate-shacl
make gate-r
echo "contract: c-m4 gates green OK"
