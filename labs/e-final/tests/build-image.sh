#!/usr/bin/env bash
# build-image.sh TAG : build the lab image with LEAN_TOOLCHAIN read from lean-toolchain; print build time and size.
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd); tag="${1:?tag}"
tc=$(tr -d '[:space:]' < "$here/lean-toolchain") || exit 2
[ -n "$tc" ] || { echo "FAIL: empty lean-toolchain"; exit 1; }
t0=$(date +%s)
docker build --platform linux/amd64 --build-arg "LEAN_TOOLCHAIN=$tc" -t "$tag" "$here/image" || { echo "FAIL: docker build"; exit 1; }
t1=$(date +%s)
echo "build_seconds=$((t1-t0)) size_bytes=$(docker image inspect "$tag" --format '{{.Size}}')"
