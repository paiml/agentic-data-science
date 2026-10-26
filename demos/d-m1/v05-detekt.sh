#!/usr/bin/env bash
# D-M1 video 5: detekt
# shellcheck source=../d-lib.sh
source "$(dirname "$0")/../d-lib.sh"
cd kotlin && gradle --no-daemon --console=plain :ads-kotlin:detekt
echo "contract: p1 detekt finds no smell OK"
