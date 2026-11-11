#!/usr/bin/env bash
# Falsifier for scripts/result-cache.sh (no Lean, runs in a second): a stored result is replayed only on an exact, intact hit;
# a missing, truncated, flipped, foreign, forged-key or garbage entry is a miss, never a replayed result.
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT; pass=0; fail=0
export ADS_GATE_CACHE="$t/c"; unset ADS_GATE_CACHE_OFF ADS_GATE_CACHE_TRACE
# shellcheck source=scripts/result-cache.sh
. "$here/scripts/result-cache.sh"
ka="$(printf 'arm a' | rc_key)"; kb="$(printf 'arm b' | rc_key)"
ok() { echo "  $1 ok"; pass=$((pass+1)); }
bad() { echo "  $1 FAIL: $2"; fail=$((fail+1)); }
hit() { # name key want-rc want-out
  if rc_get "$2" && [ "$RC_RC" = "$3" ] && [ "$RC_OUT" = "$4" ]; then ok "$1"; else bad "$1" "no exact hit (rc='${RC_RC:-}' out='${RC_OUT:-}')"; fi; }
miss() { # name key
  if rc_get "$2"; then bad "$1" "replayed a result (rc=$RC_RC)"; elif [ -z "$RC_RC$RC_OUT" ]; then ok "$1"; else bad "$1" "miss left a result behind"; fi; }
put_ab() { rm -rf "${t:?}/c"; rc_put "$ka" 1 $'RED: function Stats.x has no test\nline two'; rc_put "$kb" 0 'fn coverage OK'; }
ea="$t/c/$ka.entry"; eb="$t/c/$kb.entry"
miss 00-empty-cache "$ka"
put_ab; hit 01-roundtrip-red "$ka" 1 $'RED: function Stats.x has no test\nline two'; hit 02-roundtrip-green "$kb" 0 'fn coverage OK'
rc_put "$ka" 2 ''; hit 03-empty-output-roundtrip "$ka" 2 ''
put_ab; head -c $(( $(stat -c %s "$ea") - 20 )) "$ea" > "$t/x"; cp "$t/x" "$ea"; miss 04-truncated "$ka"
put_ab; : > "$ea"; miss 05-empty-file "$ka"
put_ab; sed -i 's/^rc 1$/rc 0/' "$ea"; miss 06-result-flipped-red-to-green "$ka"
put_ab; sed -i 's/RED: function/GREEN: function/' "$ea"; miss 07-output-edited "$ka"
put_ab; cp "$eb" "$ea"; miss 08-entry-of-another-arm-copied-over "$ka"
# a forger who also fixes the checksum still cannot move an entry to another key: the key line is checked against the file's key
put_ab; sed -i "s/^key $ka\$/key $kb/" "$ea"; head -n -1 "$ea" > "$t/y"; printf 'sum %s\n' "$(sha256sum < "$t/y" | cut -d' ' -f1)" >> "$t/y"; cp "$t/y" "$ea"; miss 09-wrong-key-with-valid-checksum "$ka"
put_ab; printf 'not a cache entry\n' > "$ea"; miss 10-garbage "$ka"
put_ab; sed -i 's/^ADS-GATE-CACHE v1$/ADS-GATE-CACHE v0/' "$ea"; miss 11-foreign-format "$ka"
put_ab; sed -i 's/^rc 1$/rc x/' "$ea"; miss 12-nonnumeric-rc "$ka"
put_ab; rm -f "${ea:?}"; mkdir "$ea"; miss 13-entry-is-a-directory "$ka"; rmdir "$ea"
put_ab; chmod 000 "$ea"; if [ "$(id -u)" = 0 ]; then ok "14-unreadable (skipped as root)"; else miss 14-unreadable "$ka"; fi; chmod 600 "$ea" 2>/dev/null
miss 15-bad-key-chars "../../etc/passwd"; miss 16-short-key "abc"
put_ab; ADS_GATE_CACHE_OFF=1 bash -c ". '$here/scripts/result-cache.sh'; rc_get '$ka' && exit 1; exit 0" && ok 17-off-never-reads || bad 17-off-never-reads "read while off"
rm -rf "${t:?}/c"; ADS_GATE_CACHE_OFF=1 bash -c ". '$here/scripts/result-cache.sh'; rc_put '$ka' 0 x"; [ ! -e "$t/c" ] && ok 18-off-never-writes || bad 18-off-never-writes "wrote while off"
# a corrupted entry is rewritten by the next real run, and then hits
put_ab; sed -i 's/^rc 1$/rc 0/' "$ea"; miss 19-corrupt-before-rewrite "$ka"; rc_put "$ka" 1 'fresh'; hit 20-rewritten-after-recompute "$ka" 1 fresh
# an unwritable dir is no error and no result
ADS_GATE_CACHE=/proc/nope bash -c ". '$here/scripts/result-cache.sh'; rc_put '$ka' 0 x; rc_get '$ka' && exit 1; exit 0" && ok 21-unwritable-dir-is-a-miss || bad 21-unwritable-dir-is-a-miss "error or hit"

# ---- rc_judge: a result enters the cache only AFTER its arm is judged; arms never read each other's entries ----
jr() { # a runner that records that it ran: prints $2 and returns $1
  echo ran >> "$t/ran"; printf '%s' "$2"; return "$1"; }
nran() { if [ -f "$t/ran" ]; then wc -l < "$t/ran"; else echo 0; fi; }
# 22: two arms with the same inputs but different expected verdicts have different keys, so neither can read the other's entry
rm -rf "${t:?}/c" "${t:?}/ran"
kx="$(printf 'same inputs\nx-red\nred\nboom' | rc_key)"; ky="$(printf 'same inputs\ny-pass\npass\n' | rc_key)"
rc_judge "$kx" x-red red boom jr 1 'RED: boom' >/dev/null; rc_judge "$ky" y-pass pass '' jr 0 'fine' >/dev/null
if [ "$(nran)" = 2 ] && [ -f "$t/c/$kx.entry" ] && [ -f "$t/c/$ky.entry" ] && [ "$kx" != "$ky" ]; then ok 22-two-arms-own-entries; else bad 22-two-arms-own-entries "ran=$(nran)"; fi
: > "$t/ran"; rc_judge "$kx" x-red red boom jr 1 'RED: boom' >/dev/null; rc_judge "$ky" y-pass pass '' jr 0 'fine' >/dev/null
if [ "$(nran)" = 0 ]; then ok 23-each-arm-hits-its-own-entry; else bad 23-each-arm-hits-its-own-entry "ran=$(nran)"; fi
# 24: an arm that wanted RED but really ran green is FAIL and stores nothing; it is never served the other arm's green entry
rm -rf "${t:?}/c" "${t:?}/ran"; rc_judge "$ky" y-pass pass '' jr 0 'fine' >/dev/null
rc_judge "$kx" x-red red boom jr 0 'fine' >/dev/null; r=$?
if [ "$r" -ne 0 ] && [ ! -f "$t/c/$kx.entry" ] && [ "$(nran)" = 2 ]; then ok 24-other-arms-green-entry-not-served; else bad 24-other-arms-green-entry-not-served "r=$r ran=$(nran)"; fi
# 25: an entry is never written before the judge decides: while the runner runs, the cache holds nothing for the key, and a
# reader in another process misses; once judged ok the entry exists
rm -rf "${t:?}/c" "${t:?}/ran"
peek() { if [ -e "$t/c/$kx.entry" ]; then echo present > "$t/peek"; else echo absent > "$t/peek"; fi
  if bash -c ". '$here/scripts/result-cache.sh'; rc_get '$kx' && exit 1; exit 0"; then echo miss > "$t/peek2"; else echo HIT > "$t/peek2"; fi
  printf 'RED: boom'; return 1; }
rc_judge "$kx" x-red red boom peek >/dev/null
if [ "$(cat "$t/peek")" = absent ] && [ "$(cat "$t/peek2")" = miss ] && [ -f "$t/c/$kx.entry" ]; then ok 25-no-entry-before-judge; else bad 25-no-entry-before-judge "$(cat "$t/peek") $(cat "$t/peek2")"; fi
rm -rf "${t:?}/c" "${t:?}/ran"; rc_judge "$kx" x-red red NOMATCH jr 1 'RED: boom' >/dev/null; r=$?
if [ "$r" -ne 0 ] && [ -z "$(ls -A "$t/c" 2>/dev/null)" ]; then ok 26-failed-verdict-never-stored; else bad 26-failed-verdict-never-stored "r=$r"; fi
# 27: a corrupted entry is refused and the arm re-runs; the rewritten entry then hits
rm -rf "${t:?}/c" "${t:?}/ran"; rc_judge "$kx" x-red red boom jr 1 'RED: boom' >/dev/null
head -c 30 "$t/c/$kx.entry" > "$t/x"; cp "$t/x" "$t/c/$kx.entry"; : > "$t/ran"
rc_judge "$kx" x-red red boom jr 1 'RED: boom' >/dev/null; n1="$(nran)"; rc_judge "$kx" x-red red boom jr 1 'RED: boom' >/dev/null
if [ "$n1" = 1 ] && [ "$(nran)" = 1 ]; then ok 27-corrupt-entry-rerun-then-hit; else bad 27-corrupt-entry-rerun-then-hit "n1=$n1 n2=$(nran)"; fi
# 28: concurrent writers of one key never expose a partial entry: 20 writers and 20 readers, every read is a miss or the whole result
rm -rf "${t:?}/c" "${t:?}/badread"; big="$(seq 1 4000 | tr '\n' ' ')"
for i in $(seq 1 20); do
  ( rc_put "$ka" 1 "$big" ) &
  ( if rc_get "$ka"; then { [ "$RC_RC" = 1 ] && [ "$RC_OUT" = "$big" ]; } || echo bad > "$t/badread"; fi; exit 0 ) &
done; wait
if [ ! -f "$t/badread" ] && rc_get "$ka" && [ "$RC_OUT" = "$big" ]; then ok 28-concurrent-put-get-never-partial; else bad 28-concurrent-put-get-never-partial "partial read"; fi
# 29: prune removes old entries and stray temp files and keeps fresh ones; 30: the gate's falsifier calls it
rm -rf "${t:?}/c"; rc_put "$ka" 0 a; rc_put "$kb" 0 b; touch -d '40 days ago' "$t/c/$ka.entry"; : > "$t/c/.tmp.stray"; touch -d '3 days ago' "$t/c/.tmp.stray"
rc_prune
if [ ! -e "$t/c/$ka.entry" ] && [ -e "$t/c/$kb.entry" ] && [ ! -e "$t/c/.tmp.stray" ]; then ok 29-prune-old-and-stray; else bad 29-prune-old-and-stray "$(ls -A "$t/c")"; fi
if grep -q '^rc_prune' "$here/scripts/falsify-lean-fn-coverage.sh"; then ok 30-prune-is-invoked-by-the-gate-falsifier; else bad 30-prune-is-invoked-by-the-gate-falsifier "no call"; fi

# ---- test-olean cache (tc_*): per-input key, atomic publish, integrity-checked ----
tcd="$t/tc"; rm -rf "${tcd:?}"; mkdir -p "$t/o"; printf 'olean-A' > "$t/o/a"; printf 'olean-B' > "$t/o/b"; printf 'src1' > "$t/s1"; printf 'src2' > "$t/s2"
k1="$(tc_ikey T "$t/s1" libhash1)"; k2="$(tc_ikey T "$t/s2" libhash1)"; k3="$(tc_ikey T "$t/s1" libhash2)"
if [ "$k1" != "$k2" ] && [ "$k1" != "$k3" ] && [ "$k2" != "$k3" ]; then ok 31-key-moves-with-source-and-library; else bad 31-key-moves-with-source-and-library "keys equal"; fi
tc_put "$tcd" "$k1" "$t/o/a"; tc_put "$tcd" "$k2" "$t/o/b"
rm -f "${t:?}/d"
if tc_get "$tcd" "$k1" "$t/d" && [ "$(cat "$t/d")" = olean-A ] && rm -f "${t:?}/d" && tc_get "$tcd" "$k2" "$t/d" && [ "$(cat "$t/d")" = olean-B ]; then ok 32-different-inputs-different-oleans; else bad 32-different-inputs-different-oleans "mixed"; fi
rm -f "${t:?}/d"; if tc_get "$tcd" "$k3" "$t/d"; then bad 33-other-library-is-a-miss "served"; else ok 33-other-library-is-a-miss; fi
printf 'tr' > "$tcd/$k1/olean"; rm -f "${t:?}/d"
if tc_get "$tcd" "$k1" "$t/d"; then bad 34-partial-olean-refused "served"; elif [ ! -e "$t/d" ]; then ok 34-partial-olean-refused; else bad 34-partial-olean-refused "left a file"; fi
tc_put "$tcd" "$k1" "$t/o/a"; rm -f "${t:?}/d"
if tc_get "$tcd" "$k1" "$t/d" && [ "$(cat "$t/d")" = olean-A ]; then ok 35-refused-entry-replaced-after-recompute; else bad 35-refused-entry-replaced-after-recompute "not healed"; fi
rm -rf "${tcd:?}" "${t:?}/tcbad"
for i in $(seq 1 12); do
  ( rm -f "${t:?}/d$i"; tc_put "$tcd" "$k1" "$t/o/a"; if tc_get "$tcd" "$k1" "$t/d$i"; then [ "$(cat "$t/d$i")" = olean-A ] || echo bad > "$t/tcbad"; fi ) &
done; wait
if [ ! -f "$t/tcbad" ] && [ "$(ls -A "$tcd" | grep -c '^\.tmp')" = 0 ] && [ "$(ls "$tcd" | wc -l)" = 1 ]; then ok 36-concurrent-publish-same-key-clean; else bad 36-concurrent-publish-same-key-clean "partial or temp left"; fi

# ---- 32 of 32: cache off, cold and warm give the same verdict table (the all-arms equality, as a test) ----
mk32() { # tab-separated rows "name want pat rc out" for 32 arms: green, red-with-match, and arms that share the same text
  local i; for i in $(seq 0 31); do
    case $((i % 4)) in
      0) printf '%02d-arm\tpass\t-\t0\tfn coverage OK %d\n' "$i" "$i";;
      1) printf '%02d-arm\tred\tRED: gap %d\t1\tRED: gap %d\n' "$i" "$i" "$i";;
      2) printf '%02d-arm\tred\tRED: gap\t1\tRED: gap shared\n' "$i";;
      3) printf '%02d-arm\tpass\t-\t0\tfn coverage OK\n' "$i";;
    esac
  done; }
table() { # <label>: judge all 32 arms in parallel (4 at a time) and print their lines in arm order
  local lbl="$1" n want pat rc out k; rm -rf "${t:?}/tab.$lbl"; mkdir -p "$t/tab.$lbl"
  while IFS=$'\t' read -r n want pat rc out; do
    [ "$pat" = - ] && pat=""
    k="$(printf 'common\n%s\n%s\n%s\n' "$n" "$want" "$pat" | rc_key)"
    while [ "$(jobs -rp | wc -l)" -ge 4 ]; do wait -n 2>/dev/null || true; done
    ( rc_judge "$k" "$n" "$want" "$pat" jr "$rc" "$out" > "$t/tab.$lbl/$n" 2>&1; echo $? >> "$t/tab.$lbl/$n" ) &
  done < <(mk32); wait; cat "$t/tab.$lbl"/*; }
rm -rf "${t:?}/c"; : > "$t/ran"
RC_OFF=1 table off > "$t/t.off"; n_off="$(nran)"; : > "$t/ran"
RC_OFF=0 table cold > "$t/t.cold"; n_cold="$(nran)"; : > "$t/ran"
table warm > "$t/t.warm"; n_warm="$(nran)"
if [ "$(grep -c ' ok$' "$t/t.off")" = 32 ] && cmp -s "$t/t.off" "$t/t.cold" && cmp -s "$t/t.off" "$t/t.warm" && [ "$n_off" = 32 ] && [ "$n_cold" = 32 ] && [ "$n_warm" = 0 ]; then ok "37-32-of-32-off-cold-warm-identical-tables"; else bad 37-32-of-32-off-cold-warm-identical-tables "ok=$(grep -c ' ok$' "$t/t.off") ran off/cold/warm=$n_off/$n_cold/$n_warm"; fi
echo "falsify-result-cache: $pass pass, $fail fail"; [ "$fail" -eq 0 ]
