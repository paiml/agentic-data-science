#!/usr/bin/env bash
# A-M1 video 3: the p1 tests, golden parity and mutants
# shellcheck source=../lib-rust.sh
source "$(dirname "$0")/../lib-rust.sh"
cargo test --locked --manifest-path rust/ads-rust/Cargo.toml --test p1
echo "contract: a-m1 v03 unit-tests OK"
