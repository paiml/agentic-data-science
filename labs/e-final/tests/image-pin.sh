#!/usr/bin/env bash
# The lab image's Dockerfile default for LEAN_TOOLCHAIN equals lean-toolchain (Coursera builds with ZERO build args), the installer is verified.
# Usage: image-pin.sh [DOCKERFILE]   (the optional path lets the falsifier check a scratch copy)
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd); d="${1:-$here/image/Dockerfile}"
tc=$(tr -d '[:space:]' < "$here/lean-toolchain") || exit 2
[ -n "$tc" ] || { echo "FAIL: lean-toolchain is empty"; exit 1; }
[ "$(grep -c '^ARG LEAN_TOOLCHAIN\(=\|$\)' "$d")" -eq 1 ] || { echo "FAIL: want exactly one ARG LEAN_TOOLCHAIN"; exit 1; }
grep -q '^ARG LEAN_TOOLCHAIN=' "$d" || { echo "FAIL: ARG LEAN_TOOLCHAIN has no default; a zero-build-arg build (Coursera) fails"; exit 1; }
def=$(sed -n 's/^ARG LEAN_TOOLCHAIN=//p' "$d" | tr -d '[:space:]')
[ "$def" = "$tc" ] || { echo "FAIL: Dockerfile default '$def' != lean-toolchain '$tc'"; exit 1; }
grep -v '^ARG LEAN_TOOLCHAIN=' "$d" | grep -q 'lean4:v' && { echo "FAIL: image/Dockerfile hard-codes a Lean version outside the ARG default"; exit 1; }
grep -q 'test -n "${LEAN_TOOLCHAIN}"' "$d" || { echo "FAIL: the empty-toolchain guard (test -n) is gone"; exit 1; }
grep -q 'sha256sum -c' "$d" || { echo "FAIL: elan installer is not sha256-verified"; exit 1; }
grep -Eq '^[0-9a-f]{64}$' "$here/image/elan-init.sh.sha256" || { echo "FAIL: elan-init.sh.sha256 is not a sha256"; exit 1; }
grep -q '"httpPort": 8080' "$here/image/manifest.json" || { echo "FAIL: manifest.json httpPort is not 8080"; exit 1; }
echo "PASS: Dockerfile default $def equals lean-toolchain; installer verified; httpPort 8080"
