#!/usr/bin/env bash
# Negative control: the shacl gate must FAIL on a known-broken example.
set -euo pipefail
d="$(mktemp -d)"
trap 'rm -rf "$d"' EXIT
src="$(git ls-files '*/example.ttl' | head -1)"
awk '/ads:readme/ {next} {print}' "$src" > "$d/example.ttl"
if SHACL_EXAMPLES="$d/example.ttl" scripts/shacl.sh > "$d/out.txt" 2>&1; then
  echo "negative control FAILED: broken example passed the gate"
  exit 1
fi
grep -q '^FAIL ' "$d/out.txt" || { echo "negative control FAILED: no FAIL line"; exit 1; }
echo "negative control OK: broken example is rejected"
