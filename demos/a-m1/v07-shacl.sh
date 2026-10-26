#!/usr/bin/env bash
# A-M1 video 7: make gate-shacl
# shellcheck source=../lib-rust.sh
source "$(dirname "$0")/../lib-rust.sh"
make gate-shacl
echo "contract: a-m1 v07 shacl OK"
