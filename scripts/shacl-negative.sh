#!/usr/bin/env bash
# Negative control: the gate-shacl task must exit non-zero on a broken file.
set -euo pipefail
tmp=$(mktemp -d)
trap 'rm -rf "${tmp:?}"' EXIT
src=$(git ls-files '*/example.ttl' | head -n 1)
[ -n "$src" ] || { echo "FAIL: no example.ttl to break"; exit 1; }
# Drop every ads:contract triple: the shape requires one (minCount 1).
grep -v 'ads:contract' "$src" > "$tmp/broken.ttl"
cmp -s "$src" "$tmp/broken.ttl" && { echo "FAIL: control broke nothing"; exit 1; }
if SHACL_NEGATIVE_CONTROL=1 SHACL_DATA_FILES="$tmp/broken.ttl" scripts/shacl.sh >"$tmp/out.txt" 2>&1; then
  echo "FAIL: gate-shacl accepted a broken file"; exit 1
fi
# A crash or parse error also exits non-zero; only Jena's own verdict counts.
grep -Eq 'sh:conforms +false' "$tmp/out.txt" || { echo "FAIL: rejected without sh:conforms false"; cat "$tmp/out.txt"; exit 1; }
echo "negative control OK: broken file rejected (sh:conforms false)"
