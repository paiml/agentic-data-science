#!/usr/bin/env bash
# B-M3 video 07-gates: the Julia gate (tests, Aqua, JET, coverage, format, examples) runs on a scratch copy
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
sc="$(mktemp -d)"
trap 'rm -rf -- "${sc:?}"' EXIT
git -C "$ADS_ROOT" ls-files -z | (cd "$ADS_ROOT" && xargs -0 cp --parents -t "$sc")
(cd "$sc" && make gate-julia 2>&1 | grep -E '^(coverage|format clean|examples OK|gate-julia OK|UNCOVERED)' | sed "s|$sc|.|")
echo "contract: b-m3 gate-julia green OK"
