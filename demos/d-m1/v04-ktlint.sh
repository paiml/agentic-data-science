#!/usr/bin/env bash
# D-M1 video 4: ktlint
# shellcheck source=../d-lib.sh
source "$(dirname "$0")/../d-lib.sh"
cd kotlin && gradle --no-daemon --console=plain :ads-kotlin:ktlintCheck
echo "contract: p1 ktlint finds no style violation OK"
