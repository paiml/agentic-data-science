#!/usr/bin/env bash
# Marker scan alone, for the course demo (ads-c05-lean 3.2.1): the same grep as scripts/gate-lean.sh's marker stage.
# It is NOT part of `make gate`; scripts/falsify-lean-scan.sh fails if its pattern ever drifts from gate-lean.sh's.
# Exit 0 and "scan: no markers" when clean; the matching lines and exit 2 when a marker is found;
# exit 1 when grep itself failed (a missing path is not a clean tree).
set -uo pipefail
cd "$(dirname "$0")/../lean/AgenticDS" || exit 1
grep -rn --include=*.lean --include=*.lean.planted -E "\b(sorry|admit)\b|native_decide|TODO|FIXME|HACK|XXX" AgenticDS.lean AgenticDS AgenticDSTest scripts
rc=$?
case $rc in
  0) exit 2 ;;
  1) echo "scan: no markers" ;;
  *) echo "scan: grep failed (rc=$rc)" >&2; exit 1 ;;
esac
