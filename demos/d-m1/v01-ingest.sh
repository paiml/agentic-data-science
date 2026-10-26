#!/usr/bin/env bash
# D-M1 video 1: typed loader and NA policy
# shellcheck source=../d-lib.sh
source "$(dirname "$0")/../d-lib.sh"
out=$(cd kotlin && gradle --no-daemon --console=plain -q :ads-kotlin:runIngest --args=../../datasets/penguins/penguins.csv 2>&1)
printf '%s\n' "$out"
grep -qx 'rows=344 kept=342' <<<"$out"
echo "contract: p1 typed ingest reads 344 rows and keeps 342 OK"
