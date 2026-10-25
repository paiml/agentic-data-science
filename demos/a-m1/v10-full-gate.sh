#!/usr/bin/env bash
# A-M1 video 10: the Rust course gates in order
# shellcheck source=../lib-rust.sh
source "$(dirname "$0")/../lib-rust.sh"
make gate-datasets gate-shacl gate-rust gate-pmat
echo "contract: a-m1 v10 full-gate OK"
