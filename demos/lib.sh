#!/usr/bin/env bash
# Shared setup for terminal demos: install agenticds into a throwaway library, never into the tree.
set -euo pipefail
ADS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ADS_ROOT
DEMO_LIB="$(mktemp -d)"
trap 'rm -rf -- "${DEMO_LIB:?}"' EXIT
mkdir -p "$DEMO_LIB/lib"
R_LIBS="${ADS_RLIB:-}" R CMD INSTALL --library="$DEMO_LIB/lib" "$ADS_ROOT/r/agenticds" >"$DEMO_LIB/install.log" 2>&1 || { tail -n 15 "$DEMO_LIB/install.log"; exit 1; }
export R_LIBS_USER="$DEMO_LIB/lib${ADS_RLIB:+:$ADS_RLIB}"
cd "$ADS_ROOT"
