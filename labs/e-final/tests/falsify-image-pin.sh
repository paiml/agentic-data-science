#!/usr/bin/env bash
# Falsifier for image-pin.sh: scratch copies of the Dockerfile must be refused (exit non-zero); the real one passes.
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd); pin="$here/tests/image-pin.sh"
S=$(mktemp -d); trap 'rm -rf "${S:?}"' EXIT; fail=0
bash "$pin" >"$S/g.out" 2>&1 && echo "arm green ok: $(tail -n 1 "$S/g.out")" || { echo "FAIL arm green: $(tail -n 1 "$S/g.out")"; fail=1; }
arm() { # name sed-expr
  sed "$2" "$here/image/Dockerfile" >"$S/$1"
  if bash "$pin" "$S/$1" >"$S/$1.out" 2>&1; then echo "FAIL arm $1: accepted"; fail=1; else echo "arm $1 RED as planned (rc=$?): $(tail -n 1 "$S/$1.out")"; fi
}
arm no-default 's|^ARG LEAN_TOOLCHAIN=.*|ARG LEAN_TOOLCHAIN|'
arm wrong-default 's|^ARG LEAN_TOOLCHAIN=.*|ARG LEAN_TOOLCHAIN=leanprover/lean4:v0.0.0|'
arm empty-default 's|^ARG LEAN_TOOLCHAIN=.*|ARG LEAN_TOOLCHAIN=|'
arm no-guard 's|test -n "${LEAN_TOOLCHAIN}"|true|'
exit "$fail"
