#!/usr/bin/env bash
# Provision the REAL toolchains for the nightly LAB lane into $RUNNER_TEMP (user space; no apt, no sudo, nothing on the host).
# A toolchain that cannot be provisioned is reported and left absent: lab-nightly.sh then says NOT RUN (exit 2), never green.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); T=${RUNNER_TEMP:?RUNNER_TEMP}
GP=${GITHUB_PATH:-/dev/null}; GE=${GITHUB_ENV:-/dev/null}
h=5c61cb4b40332cb5a3504e7779e2f5dac093caa4a1116ded19f01413f85c63e4
if curl -fsSL -o "$T/julia.tgz" "https://julialang-s3.julialang.org/bin/linux/x64/1.13/julia-1.13.3-linux-x86_64.tar.gz" \
   && echo "$h  $T/julia.tgz" | sha256sum -c - >/dev/null && tar -xzf "$T/julia.tgz" -C "$T"; then
  echo "$T/julia-1.13.3/bin" >> "$GP"; echo "julia: installed"
else echo "julia: NOT INSTALLED"; fi
if "$here/install-r.sh" "$T/r" >/dev/null && "$here/r-deps.sh" "$T/rlib" >/dev/null; then
  { echo "$T/r/4.6.1/bin" >> "$GP"; echo "R_LIBS=$T/rlib" >> "$GE"; }; echo "R: installed"
else echo "R: NOT INSTALLED"; fi
command -v cargo >/dev/null && echo "cargo: present" || echo "cargo: NOT PRESENT"
exit 0
