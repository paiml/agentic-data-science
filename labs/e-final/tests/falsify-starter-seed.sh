#!/usr/bin/env bash
# Falsifier for starter-seed.sh: scratch copies without the COPY or the seed line are refused; the real files pass.
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd); t="$here/tests/starter-seed.sh"
S=$(mktemp -d); trap 'rm -rf "${S:?}"' EXIT; fail=0
bash "$t" >"$S/g.out" 2>&1 && echo "arm green ok: $(tail -n 1 "$S/g.out")" || { echo "FAIL arm green: $(tail -n 1 "$S/g.out")"; fail=1; }
grep -v '^COPY --chown=coder:coder starter/' "$here/image/Dockerfile" >"$S/Dockerfile.nocopy"
grep -v 'cp -n /home/coder/starter/Mean.lean' "$here/image/start.sh" >"$S/start.noseed"
for a in "$S/Dockerfile.nocopy $here/image/start.sh" "$here/image/Dockerfile $S/start.noseed"; do
  # shellcheck disable=SC2086
  if bash "$t" $a >"$S/a.out" 2>&1; then echo "FAIL arm accepted: $a"; fail=1; else echo "arm RED as planned: $(tail -n 1 "$S/a.out")"; fi
done
exit "$fail"
