#!/usr/bin/env bash
# Marker scan alone, for the course demo (ads-c05-lean 3.2.1): the same grep as scripts/gate-lean.sh's marker stage.
# It is NOT part of `make gate`; scripts/falsify-lean-scan.sh fails if its pattern ever drifts from gate-lean.sh's.
# Exit 0 and "scan: no markers" when clean; the matching lines and exit 2 when a marker is found.
set -uo pipefail
cd "$(dirname "$0")/../lean/AgenticDS" || exit 1
if grep -rn --include=*.lean --include=*.lean.planted -E "\b(sorry|admit)\b|native_decide|TODO|FIXME|HACK|XXX" AgenticDS.lean AgenticDS AgenticDSTest scripts; then exit 2; fi
echo "scan: no markers"
