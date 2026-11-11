#!/usr/bin/env bash
# Falsify the .gitleaks.toml allowlist with generated fixtures (nothing secret-shaped is committed).
# Usage: scripts/gitleaks-selftest.sh <gitleaks-binary> <config>
set -euo pipefail
gl="$(readlink -f "${1:?gitleaks binary}")"; cfg="$(readlink -f "${2:?config}")"
w="$(mktemp -d)"; trap 'rm -rf "${w:?}"' EXIT
mkdir -p "$w/uuid/julia/X" "$w/key/julia/Y" "$w/key2" "$w/other"
u1=94b1ba4f-4ee9-5380-92f1-94cde586c3c5; u2=8f75cd03-7ff8-4ecb-9b8f-daf728133b1b
printf 'AxisKeys = "%s"\noneAPI = "%s"\n' "$u1" "$u2" > "$w/uuid/julia/X/Manifest.toml"
cp "$w/uuid/julia/X/Manifest.toml" "$w/key/julia/Y/Manifest.toml"
printf 'stripe = "%s"\n' "sk_""live_""4eC39HqLyjWDarjtT1zdp7dc" >> "$w/key/julia/Y/Manifest.toml"
printf 'apiKey = "%s"\n' "Zq8vK3mPx9LtR2wYb7NcJ5hD" >> "$w/key2/Manifest.toml"
cp "$w/uuid/julia/X/Manifest.toml" "$w/other/notes.toml"
scan() { "$gl" dir "$1" --config "$cfg" --no-banner --redact --exit-code 1 >/dev/null 2>&1; }
# 1 baseline: without the allowlist the UUID lines alert (fixture is meaningful)
if "$gl" dir "$w/uuid" --no-banner --redact --exit-code 1 >/dev/null 2>&1; then echo "FAIL: fixture does not fire on default rules"; exit 1; fi
# 2 UUID-only Manifest.toml is quiet
scan "$w/uuid" || { echo "FAIL: Manifest UUID lines alert"; exit 1; }
# 3 a real-looking key inside Manifest.toml still alerts
if scan "$w/key"; then echo "FAIL: key in Manifest.toml suppressed"; exit 1; fi
# 3b a non-UUID high-entropy value in Manifest.toml alerts (fails if the value regex is ever dropped)
if scan "$w/key2"; then echo "FAIL: non-UUID value in Manifest.toml suppressed"; exit 1; fi
# 4 the same UUID lines in another file still alert
if scan "$w/other"; then echo "FAIL: UUID outside Manifest.toml suppressed"; exit 1; fi
echo "gitleaks selftest: OK"
