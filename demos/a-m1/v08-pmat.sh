#!/usr/bin/env bash
# A-M1 video 8: make gate-pmat
# shellcheck source=../lib-rust.sh
source "$(dirname "$0")/../lib-rust.sh"
make gate-pmat
echo "contract: a-m1 v08 pmat OK"
