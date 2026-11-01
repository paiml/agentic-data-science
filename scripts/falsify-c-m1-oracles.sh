#!/usr/bin/env bash
# F2: the c-m1 demo oracles enforce their contract at runtime. Clean data: exit 0 and a "contract: ... OK" line.
# One CSV data row deleted (scratch copy): non-zero exit and no OK line. Needs Rscript with jsonlite, cli, readr.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT
mkdir -p "$t/clean" "$t/mut"
for d in clean mut; do cp -r "$root/datasets" "$t/$d/datasets"; done
csv="$t/mut/datasets/penguins/penguins.csv"; n=$(wc -l < "$csv")
sed -i '5d' "$csv"
[ "$(wc -l < "$csv")" -lt "$n" ] || { echo "FAIL: mutation did not change the CSV"; exit 1; }
for o in v01-ticket v02-ingest; do
  f="$root/demos/c-m1/$o/oracle.R"
  out=$(cd "$t/clean" && Rscript "$f" 2>&1) || { echo "FAIL: $o clean data exited non-zero"; echo "$out" | tail -5; exit 1; }
  echo "$out" | grep -q 'contract: .* OK' || { echo "FAIL: $o clean run printed no contract OK line"; exit 1; }
  if out=$(cd "$t/mut" && Rscript "$f" 2>&1); then echo "FAIL: $o stayed green with a row deleted"; exit 1; fi
  echo "$out" | grep -q 'contract: .* OK' && { echo "FAIL: $o printed OK on the mutant"; exit 1; }
done
echo "F2 OK: both oracles pass clean data and exit non-zero with a CSV row deleted"
