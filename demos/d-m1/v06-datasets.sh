#!/usr/bin/env bash
# D-M1 video 6: dataset gate
# shellcheck source=../d-lib.sh
source "$(dirname "$0")/../d-lib.sh"
make gate-datasets
echo "contract: dataset checksums and licences verified OK"
