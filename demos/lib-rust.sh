#!/usr/bin/env bash
# Shared setup for the Rust terminal demos: tools by absolute dir, build output outside the tree.
# The recorded session runs under a hermetic env (HOME=/tmp, system PATH only), so this script
# resolves the real home and sets what cargo, make, jq, pmat and Jena need itself.
set -euo pipefail
umask 022
REAL_HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"
export PATH="$REAL_HOME/.cargo/bin:$REAL_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
export CARGO_HOME="$REAL_HOME/.cargo" RUSTUP_HOME="$REAL_HOME/.rustup"
export CARGO_TARGET_DIR="${ADS_TARGET:-/tmp/ads-rust-target}"
ADS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ADS_ROOT
cd "$ADS_ROOT"
