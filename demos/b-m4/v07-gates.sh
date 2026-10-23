#!/usr/bin/env bash
# B-M4 video 07-gates: datasets, SHACL and the Julia gate on a scratch copy
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
make gate-datasets
make gate-shacl
sc="$(mktemp -d)"
trap 'rm -rf -- "${sc:?}"' EXIT
git -C "$ADS_ROOT" ls-files -z | (cd "$ADS_ROOT" && xargs -0 cp --parents -t "$sc")
out="$(cd "$sc" && make gate-julia 2>&1 | grep -E '^(coverage|format clean|examples OK|gate-julia OK|UNCOVERED)' | sed "s|$sc|.|")"
echo "$out"
echo "$out" | grep -q '^gate-julia OK'
echo "contract: b-m4 datasets, SHACL and Julia gates green OK"
