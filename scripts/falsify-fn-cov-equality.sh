#!/usr/bin/env bash
# All-arms equality of the result cache (real Lean; run after `lake build`): the whole falsify-lean-fn-coverage.sh suite is run
# with the cache off, cold and warm. The three verdict tables must be byte-identical and every arm must be ok, so a cache hit is
# indistinguishable from a fresh run for ALL arms, not for a sample. A warm run must be all hits, a cold run all misses.
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/.elan/bin:$PATH"
t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT
export ADS_GATE_CACHE="$t/cache"
narms="$(grep -cE '(^|; )arm [0-9][0-9]-' "$here/scripts/falsify-lean-fn-coverage.sh")"
run() { # <label> [VAR=val ...]: table in $t/<label>.out, exit code in $t/<label>.rc, seconds in $t/<label>.s
  local label="$1" s0=$SECONDS; shift
  : > "$t/trace"
  env "$@" ADS_GATE_CACHE_TRACE="$t/trace" bash "$here/scripts/falsify-lean-fn-coverage.sh" > "$t/$label.out" 2>&1; echo $? > "$t/$label.rc"
  echo $((SECONDS - s0)) > "$t/$label.s"
}
cnt() { grep -c "^$1 " "$t/trace" 2>/dev/null || true; }
run off ADS_GATE_CACHE_OFF=1; offtrace="$(cnt hit)$(cnt miss)"
run cold; cold_miss="$(cnt miss)"; cold_hit="$(cnt hit)"
run warm; warm_miss="$(cnt miss)"; warm_hit="$(cnt hit)"
pass=0; fail=0
ok() { echo "  $1 ok"; pass=$((pass+1)); }
bad() { echo "  $1 FAIL: $2"; fail=$((fail+1)); }
n_ok() { grep -c ' ok$' "$t/$1.out" || true; }
if [ "$(cat "$t/off.rc")" = 0 ] && [ "$(n_ok off)" = "$narms" ] && grep -q "$narms passed, 0 failed" "$t/off.out"; then ok "00-uncached-all-$narms-arms-ok"; else bad "00-uncached-all-$narms-arms-ok" "ok=$(n_ok off) of $narms"; tail -5 "$t/off.out"; fi
if [ "$offtrace" = 00 ]; then ok 01-uncached-never-touches-the-cache; else bad 01-uncached-never-touches-the-cache "trace=$offtrace"; fi
if cmp -s "$t/off.out" "$t/cold.out" && [ "$(cat "$t/cold.rc")" = "$(cat "$t/off.rc")" ] && [ "$cold_miss" = "$narms" ] && [ "$cold_hit" = 0 ]; then ok "02-cold-table-equals-uncached-$narms-of-$narms"; else bad "02-cold-table-equals-uncached-$narms-of-$narms" "miss=$cold_miss hit=$cold_hit"; diff "$t/off.out" "$t/cold.out" | head -5; fi
if cmp -s "$t/off.out" "$t/warm.out" && [ "$(cat "$t/warm.rc")" = "$(cat "$t/off.rc")" ] && [ "$warm_hit" = "$narms" ] && [ "$warm_miss" = 0 ]; then ok "03-warm-table-equals-uncached-$narms-of-$narms"; else bad "03-warm-table-equals-uncached-$narms-of-$narms" "miss=$warm_miss hit=$warm_hit"; diff "$t/off.out" "$t/warm.out" | head -5; fi
echo "  seconds: uncached $(cat "$t/off.s") cold $(cat "$t/cold.s") warm $(cat "$t/warm.s")"
echo "falsify-fn-cov-equality: $pass pass, $fail fail"; [ "$fail" -eq 0 ]
