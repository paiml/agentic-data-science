#!/usr/bin/env bash
# Shared setup for terminal demos: run from the repo root, depot from ADS_JULIA_DEPOT when set.
set -euo pipefail
ADS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ADS_ROOT
[ -z "${ADS_JULIA_DEPOT:-}" ] || export JULIA_DEPOT_PATH="$ADS_JULIA_DEPOT"
export JULIA_PKG_PRECOMPILE_AUTO=0
cd "$ADS_ROOT"
PKG="$ADS_ROOT/julia/AgenticDS.jl"
export PKG
julia --project="$PKG" -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()' >/dev/null 2>&1
