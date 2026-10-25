#!/usr/bin/env bash
# A-M1 video 9: make gate-rust
# shellcheck source=../lib-rust.sh
source "$(dirname "$0")/../lib-rust.sh"
make gate-rust
echo "contract: a-m1 v09 rust-gate OK"
