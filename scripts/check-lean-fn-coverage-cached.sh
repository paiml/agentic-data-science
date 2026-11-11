#!/usr/bin/env bash
# check-lean-fn-coverage.sh on the real package, replaying its GREEN output when no input changed (scripts/result-cache.sh).
# Only a green result is ever stored or replayed: a red always runs the real check, so its message is first-hand.
# Same stdout and exit code as the plain check; ADS_GATE_CACHE_OFF=1 runs the check directly.
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/result-cache.sh
. "$here/scripts/result-cache.sh"
export PATH="$HOME/.elan/bin:$PATH"
if [ "$#" -eq 0 ] && [ -z "${LEAN_PKG:-}${LEAN_REAL:-}${REFUSALS:-}${RUN_LIST:-}${TEST_CACHE:-}${LEAN_PLOT:-}${LEAN_PLOT_ARMS:-}${WALK_OUT:-}" ]; then
  key="$( { rc_lean_inputs "$here" "$here/lean/AgenticDS" "$0"; echo real-package-check; } | rc_key)"
  if rc_get "$key" && [ "$RC_RC" = 0 ]; then printf '%s\n' "$RC_OUT"; exit 0; fi
fi
out="$(bash "$here/scripts/check-lean-fn-coverage.sh" "$@" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || [ -z "${key:-}" ] || rc_put "$key" 0 "$out"
printf '%s\n' "$out"; exit "$rc"
