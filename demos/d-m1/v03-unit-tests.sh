#!/usr/bin/env bash
# D-M1 video 3: unit tests
# shellcheck source=../d-lib.sh
source "$(dirname "$0")/../d-lib.sh"
cd kotlin && gradle --no-daemon --console=plain :ads-kotlin:test
echo "contract: p1 JUnit tests pass OK"
