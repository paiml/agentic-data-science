#!/usr/bin/env bash
# D-M1 video 8: kover coverage
# shellcheck source=../d-lib.sh
source "$(dirname "$0")/../d-lib.sh"
cd kotlin && gradle --no-daemon --console=plain :ads-kotlin:test :ads-kotlin:koverVerify
echo "contract: p1 coverage meets the kover floor OK"
