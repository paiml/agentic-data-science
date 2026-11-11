#!/usr/bin/env bash
# Anscombe lesson, Julia: stdout.txt + plot.svg + manifest.sha256 from the pinned container (ADS-DEMO-001 R-2, R-7).
# Usage: scripts/anscombe-julia.sh OUTDIR     Needs docker. The run has no network; the depot is warmed first (network step).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:?usage: anscombe-julia.sh OUTDIR}"
# julia:1.13.3, pinned by digest, never by tag.
img="julia@sha256:78a619b71166a46adbfe438a209275a096f7b534814646b1abe2541e4e0eeccc"
mkdir -p "$out" "$root/.depot"
out="$(cd "$out" && pwd)"
u="$(id -u):$(id -g)"
common=(--rm -u "$u" -e HOME=/tmp -e JULIA_DEPOT_PATH=/depot -v "$root/.depot:/depot")
# Step 1 (network): resolve nothing new; install exactly what Manifest.toml pins.
docker run "${common[@]}" -v "$root:/w:ro" -w /w/julia/Anscombe "$img" \
  julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()' > /dev/null
# Step 2 (no network, read-only tree): run the lesson.
docker run "${common[@]}" --network none -v "$root:/w:ro" -v "$out:/out" -w /w "$img" \
  julia --project=julia/Anscombe -e 'using Anscombe; Anscombe.main("data/anscombe/anscombe.csv", "/out")' > "$out/stdout.txt"
(
  cd "$root"
  sha256sum data/anscombe/anscombe.csv julia/Anscombe/Manifest.toml julia/Anscombe/Project.toml julia/Anscombe/src/Anscombe.jl
  cd "$out"
  sha256sum stdout.txt plot.svg
  echo "container $img"
) > "$out/manifest.sha256"
cat "$out/manifest.sha256"
