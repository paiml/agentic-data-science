#!/usr/bin/env bash
# F2: the c-m1 demo oracles enforce their contract at runtime. Clean data: exit 0 and a "contract: ... OK" line.
# One COMPLETE data row deleted (line 10, scratch copy; not the all-NA row): non-zero exit, no OK line, and the clause that
# must trip names itself: v01 the checksum (sha_ok), v02 the row count (nrow(raw) == 344). Needs Rscript with jsonlite, cli, readr.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT
mkdir -p "$t/clean" "$t/mut"
for d in clean mut; do cp -r "$root/datasets" "$t/$d/datasets"; done
csv="$t/mut/datasets/penguins/penguins.csv"; n=$(wc -l < "$csv")
row=$(sed -n 10p "$csv")
[ "$(printf '%s' "$row" | tr -cd ',' | wc -c)" -eq 7 ] && ! printf '%s' "$row" | grep -Eq '^NA(,NA)*$|^,*$' || { echo "FAIL: line 10 is not a complete data row: $row"; exit 1; }
sed -i '10d' "$csv"
[ "$(wc -l < "$csv")" -lt "$n" ] || { echo "FAIL: mutation did not change the CSV"; exit 1; }
for o in v01-ticket:sha_ok v02-ingest:'nrow\(raw\) == 344'; do
  name=${o%%:*}; clause=${o#*:}
  f="$root/demos/c-m1/$name/oracle.R"
  out=$(cd "$t/clean" && Rscript "$f" 2>&1) || { echo "FAIL: $name clean data exited non-zero"; echo "$out" | tail -5; exit 1; }
  echo "$out" | grep -q 'contract: .* OK' || { echo "FAIL: $name clean run printed no contract OK line"; exit 1; }
  if out=$(cd "$t/mut" && Rscript "$f" 2>&1); then echo "FAIL: $name stayed green with a row deleted"; exit 1; fi
  echo "$out" | grep -q 'contract: .* OK' && { echo "FAIL: $name printed OK on the mutant"; exit 1; }
  echo "$out" | grep -Eq "$clause" || { echo "FAIL: $name went red but not on its clause /$clause/: $(echo "$out" | tail -2)"; exit 1; }
done
echo "F2 OK: both oracles pass clean data and go red on their own clause (checksum, nrow == 344) with a complete row deleted"
