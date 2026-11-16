#!/usr/bin/env bash
# Drop-in `julia` for hosts without one: the pinned sandbox image, network off, non-root, stdin forwarded.
# Mounts the grade.sh scratch parent (cwd's parent) read-write and GRADER_DIR read-only at the same paths.
# Usage: JULIA=$PWD/julia-docker.sh ./grade.sh   (IMG overrides the image)
IMG=${IMG:-127.0.0.1:5000/ads-julia-render:rev3}
p=$(dirname "$PWD")
exec docker run --rm -i --network none --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -e JULIA_DEPOT_PATH=/tmp/jd:/opt/depot -e JULIA_PKG_OFFLINE=true \
  -v "$p:$p" -v "${GRADER_DIR:-/grader}:${GRADER_DIR:-/grader}:ro" ${EXTRA_MOUNT:+-v "$EXTRA_MOUNT"} -w "$PWD" "$IMG" julia "$@"
