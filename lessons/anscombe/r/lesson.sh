#!/usr/bin/env bash
# Run the R Anscombe lesson in the pinned image; emit stdout.txt, plot.svg, manifest.sha256 into OUT.
# usage: lesson.sh OUT_DIR   (needs docker; builds from a clean git export of HEAD)
set -euo pipefail
out="${1:?usage: lesson.sh OUT_DIR}"
root="$(git rev-parse --show-toplevel)"
ctx="$(mktemp -d)"; trap 'rm -rf "${ctx:?}"' EXIT
git -C "$root" archive HEAD | tar -x -C "$ctx"
docker build -q -t ads-anscombe-r -f "$ctx/lessons/anscombe/r/Dockerfile" "$ctx" >/dev/null
mkdir -p "$out"
docker run --rm --network none --user "$(id -u):$(id -g)" -v "$(cd "$out" && pwd):/out" ads-anscombe-r \
  sh -c 'Rscript lessons/anscombe/r/run.R data/anscombe /out >&2'
( cd "$out" && sha256sum stdout.txt plot.svg > manifest.sha256 )
