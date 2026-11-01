#!/usr/bin/env bash
# Cross-language parity (ADS-DEMO-001 R-4): every language's stdout.txt for a lesson must be byte-identical.
# usage: parity.sh <dir containing <lang>/stdout.txt ...>   Exit 1 on any mismatch or fewer than 1 language.
set -euo pipefail
d="$1"; n=0; ref=""
for f in "$d"/*/stdout.txt; do
  [ -s "$f" ] || { echo "FAIL: empty or missing $f"; exit 1; }
  h=$(sha256sum "$f" | cut -d' ' -f1); n=$((n+1))
  if [ -z "$ref" ]; then ref="$h"; first="$f"; elif [ "$h" != "$ref" ]; then echo "FAIL parity: $f differs from $first"; diff "$first" "$f" || true; exit 1; fi
done
[ "$n" -ge 1 ] || { echo "FAIL: no languages under $d"; exit 1; }
echo "parity OK: $n language(s)"
