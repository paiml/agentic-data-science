#!/usr/bin/env bash
# build-image.sh TAG : build the lab image with ZERO --build-arg flags (the Dockerfile default carries the toolchain, as on Coursera); print build time and size.
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd); tag="${1:?tag}"
# image-pin.sh proves the Dockerfile default equals lean-toolchain; no build arg is passed here on purpose.
t0=$(date +%s)
docker build --platform linux/amd64 -t "$tag" "$here/image" || { echo "FAIL: docker build"; exit 1; }
t1=$(date +%s)
echo "build_seconds=$((t1-t0)) size_bytes=$(docker image inspect "$tag" --format '{{.Size}}')"
