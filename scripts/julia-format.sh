#!/usr/bin/env bash
# JuliaFormatter check (no diff, no rewrite) over a whole Julia package directory.
# Usage: scripts/julia-format.sh <dir>
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
[ -z "${ADS_JULIA_DEPOT:-}" ] || export JULIA_DEPOT_PATH="$ADS_JULIA_DEPOT"
dir="$(cd "$1" && pwd)"
gate="$root/julia/gate"
julia --project="$gate" -e 'using Pkg; Pkg.instantiate()'
julia --project="$gate" -e '
using JuliaFormatter
ok = format(ARGS[1]; verbose = false, overwrite = false)
println("format clean: ", ok)
ok || exit(1)
' "$dir"
