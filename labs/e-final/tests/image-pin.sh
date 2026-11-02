#!/usr/bin/env bash
# The lab image takes its Lean toolchain from lean-toolchain (a build arg), never from a literal in the Dockerfile, and verifies the elan installer.
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd); d="$here/image/Dockerfile"
tc=$(tr -d '[:space:]' < "$here/lean-toolchain") || exit 2
[ -n "$tc" ] || { echo "FAIL: lean-toolchain is empty"; exit 1; }
grep -q 'lean4:v' "$d" && { echo "FAIL: image/Dockerfile hard-codes a Lean version; read lean-toolchain"; exit 1; }
[ "$(grep -c '^ARG LEAN_TOOLCHAIN$' "$d")" -eq 1 ] || { echo "FAIL: want exactly one ARG LEAN_TOOLCHAIN"; exit 1; }
grep -q 'sha256sum -c' "$d" || { echo "FAIL: elan installer is not sha256-verified"; exit 1; }
grep -Eq '^[0-9a-f]{64}$' "$here/image/elan-init.sh.sha256" || { echo "FAIL: elan-init.sh.sha256 is not a sha256"; exit 1; }
grep -q '"httpPort": 8080' "$here/image/manifest.json" || { echo "FAIL: manifest.json httpPort is not 8080"; exit 1; }
echo "PASS: toolchain $tc comes from lean-toolchain; installer verified; httpPort 8080"
