#!/usr/bin/env bash
# Runs all 20 M1-M2 demos twice each (rerun-lean-demos.sh: exit 0, non-empty stdout, identical output and plots, contract line);
# exit 0 only if every demo is 2/2.
set -uo pipefail
cd "${PKG:-/w/lean/AgenticDS}" || exit 2
ids=""; for m in 1 2; do for v in 01 02 03 04 05 06 07 08 09 10; do ids="$ids m${m}v$v"; done; done
# shellcheck disable=SC2086
bash scripts/rerun-lean-demos.sh 2 .lake/build/bin $ids
