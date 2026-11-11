#!/usr/bin/env bash
# Falsifier for emit-demo-json.sh (ads#194 FIX-THEN-PASS): a failing jq must make the script exit non-zero and leave no OUT file.
# Arms: A jq fails on --rawfile (row write), B jq fails on the sentinel commit arg (final jq only), C jq fails on plots (-R), E real jq must pass.
# A-C must fail, E must pass. Run from lean/AgenticDS.
set -uo pipefail
S=$(mktemp -d); trap 'rm -rf "${S:?}"' EXIT
REAL=$(command -v jq) || { echo "no jq" >&2; exit 2; }
mkdir -p "$S/bin" "$S/stub" "$S/w"
printf '#!/usr/bin/env bash\necho "contract: x OK"\n' >"$S/bin/example-m9"; chmod +x "$S/bin/example-m9"
mkjq() { printf '#!/usr/bin/env bash\nfor a in "$@"; do [ "$a" = "%s" ] && exit 5; done\nexec %s "$@"\n' "$1" "$REAL" >"$S/stub/jq"; chmod +x "$S/stub/jq"; }
SCR=$PWD/scripts/emit-demo-json.sh; fail=0
arm() { # name want(1 = must fail) flag
  rm -f "${S:?}/w/out.json"; mkjq "$3"
  ( cd "$S/w" && PATH="$S/stub:$PATH" CONTRACT_LIST=/dev/null "$SCR" "$S/bin" "$S/w/out.json" m9v01 ) >"$S/o" 2>&1; rc=$?
  if [ "$2" = 1 ]; then
    if [ "$rc" -ne 0 ] && [ ! -e "$S/w/out.json" ]; then echo "arm $1 ok (rc=$rc, no OUT)"; else echo "FAIL arm $1: rc=$rc OUT=$([ -e "$S/w/out.json" ] && echo present || echo absent)"; fail=1; fi
  else
    if [ "$rc" -eq 0 ] && [ -s "$S/w/out.json" ]; then echo "arm $1 ok"; else echo "FAIL arm $1: rc=$rc $(cat "$S/o")"; fail=1; fi
  fi
}
arm A-rawfile 1 --rawfile
# B: only the FINAL jq carries --arg commit $GITHUB_SHA; -s alone also hits the plots step, so it proved nothing about the final jq.
export GITHUB_SHA=falsify-sentinel
arm B-final-jq 1 falsify-sentinel
unset GITHUB_SHA
arm C-plots-R 1 -R
arm E-good 0 --never-matches
[ "$fail" -eq 0 ] && echo "falsifier OK (4 arms)"
exit "$fail"
