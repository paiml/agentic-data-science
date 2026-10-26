#!/usr/bin/env bash
# D-M1 video 7: SHACL gate
# shellcheck source=../d-lib.sh
source "$(dirname "$0")/../d-lib.sh"
make gate-shacl
echo "contract: SHACL shapes conform OK"
