#!/usr/bin/env bash
# Per-job wiring of the toolchain download cache (ANDON ci-flake). Prints the first missing piece, exit 1.
# usage: check-dl-cache-wiring.sh WORKFLOW_FILE JOB KIND CONSUMER [EXTRA_KEY_PREFIX EXTRA_PATH]
#   KIND      elan|gradle: the cache key must start dl-KIND-
#   CONSUMER  the script the job runs after the cache step (it calls dl-cached.sh, which verifies the sha)
#   EXTRA_*   a second cache step the job must also have (a path and a key prefix), e.g. the Lean toolchain
set -uo pipefail
f=$1; job=$2; kind=$3; consumer=$4; xk=${5:-}; xp=${6:-}
blk="$(awk -v j="  $job:" '$0==j{p=1;next} p&&/^  [A-Za-z0-9_-]+:/{exit} p' "$f")"
[ -n "$blk" ] || { echo "$f: job $job not found"; exit 1; }
echo "$blk" | grep -qE 'ADS_DL_CACHE: \$\{\{ github\.workspace \}\}/\.dl-cache$' || { echo "$f $job: env ADS_DL_CACHE is missing or moved"; exit 1; }
# a cache step = 'uses: actions/cache@v4' plus the next 6 lines; one must carry both the path and the key
ok=""
while IFS=: read -r ln _; do
  s="$(echo "$blk" | sed -n "${ln},$((ln + 6))p")"
  echo "$s" | grep -qE 'path: \$\{\{ github\.workspace \}\}/\.dl-cache$' && echo "$s" | grep -qE "key: dl-$kind-" && { ok=$ln; break; }
done < <(echo "$blk" | grep -n 'uses: actions/cache@v4')
[ -n "$ok" ] || { echo "$f $job: no actions/cache@v4 step with path .dl-cache and key dl-$kind-"; exit 1; }
c="$(echo "$blk" | grep -n "run:.*$consumer" | head -1 | cut -d: -f1)"
[ -n "$c" ] || { echo "$f $job: no run step calls $consumer"; exit 1; }
[ "$c" -gt "$ok" ] || { echo "$f $job: $consumer runs before the cache is restored"; exit 1; }
if [ -n "$xk" ]; then
  okx=""
  while IFS=: read -r ln _; do
    s="$(echo "$blk" | sed -n "${ln},$((ln + 6))p")"
    echo "$s" | grep -qF "$xp" && echo "$s" | grep -qE "key: $xk" && okx=1
  done < <(echo "$blk" | grep -n 'uses: actions/cache@v4')
  [ -n "$okx" ] || { echo "$f $job: no actions/cache@v4 step with path $xp and key $xk"; exit 1; }
fi
exit 0
