#!/usr/bin/env bash
# A-M1 video 2: run a-m1-p1-profile
# shellcheck source=../lib-rust.sh
source "$(dirname "$0")/../lib-rust.sh"
cargo run -q --locked --manifest-path rust/ads-rust/Cargo.toml --example a-m1-p1-profile
echo "contract: a-m1 v02 example-two OK"
