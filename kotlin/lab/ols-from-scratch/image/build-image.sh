#!/usr/bin/env bash
# build-image.sh TAG : build the Kotlin lab image from a clean git export (never the working tree); print build time and size.
set -uo pipefail
repo=$(cd "$(dirname "$0")/../../../.." && pwd); tag="${1:?tag}"
ctx=$(mktemp -d) || exit 2
trap 'rm -rf "${ctx:?}"' EXIT
git -C "$repo" archive HEAD kotlin/lab/ols-from-scratch datasets/penguins | tar -x -C "$ctx" || { echo "FAIL: git archive"; exit 1; }
t0=$(date +%s)
docker build --platform linux/amd64 -f "$ctx/kotlin/lab/ols-from-scratch/image/Dockerfile" -t "$tag" "$ctx" || { echo "FAIL: docker build"; exit 1; }
t1=$(date +%s)
echo "build_seconds=$((t1-t0)) size_bytes=$(docker image inspect "$tag" --format '{{.Size}}')"
