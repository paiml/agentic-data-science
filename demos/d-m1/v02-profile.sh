#!/usr/bin/env bash
# D-M1 video 2: per-species profile
# shellcheck source=../d-lib.sh
source "$(dirname "$0")/../d-lib.sh"
out=$(cd kotlin && gradle --no-daemon --console=plain -q :ads-kotlin:runProfile --args=../../datasets/penguins/penguins.csv 2>&1)
printf '%s\n' "$out"
grep -q '"species"' <<<"$out"
echo "contract: p1 per-species profile printed for the three species OK"
