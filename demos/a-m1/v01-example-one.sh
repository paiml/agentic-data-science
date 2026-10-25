#!/usr/bin/env bash
# A-M1 video 1: run a-m1-p1
# shellcheck source=../lib-rust.sh
source "$(dirname "$0")/../lib-rust.sh"
cargo run -q --locked --manifest-path rust/ads-rust/Cargo.toml --example a-m1-p1
echo "contract: a-m1 v01 example-one OK"
