#!/usr/bin/env bash
# Falsifier for the toolchain download cache (ANDON ci-flake, 2026-11-09). Offline: file:// URLs.
# Asserts on the real dl-cached.sh, then on a mutant with the post-fetch verify removed, which must FAIL.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT
printf 'toolchain-bytes\n' > "$t/src"; good="$(sha256sum "$t/src" | cut -d' ' -f1)"; bad="$(printf x | sha256sum | cut -d' ' -f1)"
asserts() { # $1 = script under test; prints the first failed assertion
  local s="$1" c="$t/c.$RANDOM"; export ADS_DL_CACHE="$c"
  bash "$s" "file://$t/src" "$good" "$t/o1" 2>/dev/null && cmp -s "$t/src" "$t/o1" || { echo "miss did not fetch+verify"; return 1; }
  bash "$s" "file://$t/gone" "$good" "$t/o2" 2>/dev/null && cmp -s "$t/src" "$t/o2" || { echo "hit touched the network"; return 1; }
  rm -rf "${c:?}"
  bash "$s" "file://$t/src" "$bad" "$t/o3" 2>/dev/null && { echo "wrong pin accepted after fetch"; return 1; }
  [ ! -e "$t/o3" ] && [ ! -e "$c/$bad" ] || { echo "wrong-pin bytes kept"; return 1; }
  mkdir -p "$c"; printf 'tampered\n' > "$c/$good"
  bash "$s" "file://$t/gone" "$good" "$t/o4" 2>/dev/null && { echo "tampered cache entry used"; return 1; }
  return 0
}
r="$(asserts "$root/scripts/dl-cached.sh")" || { echo "FAIL real script: $r"; exit 1; }
sed '/if ! check "\$c.part"/d' "$root/scripts/dl-cached.sh" > "$t/mutant.sh"
asserts "$t/mutant.sh" >/dev/null && { echo "FAIL mutant without post-fetch verify passed"; exit 1; }
w="$root/.github/workflows"
# Per-job wiring: each job that fetches a toolchain keeps its cache step, env and consumer, in order
# (check-dl-cache-wiring.sh). Then each piece is deleted or bent in turn in a copy; every mutant must be RED.
chk="$root/scripts/check-dl-cache-wiring.sh"
JOBS="ci.yml|lean|elan|install-elan.sh||
ci.yml|anscombe-lean|elan|install-elan.sh|lean-tc-anscombe-|~/.elan/toolchains
ci.yml|kotlin-anscombe|gradle|anscombe-artifacts.sh||
anscombe.yml|artifacts|gradle|anscombe-artifacts.sh||"
mutate() { # FILE JOB MODE: dropcache droptc dropenv key path dropconsumer
  awk -v j="  $2:" -v m="$3" '
    { inj = ($0 == j) ? 1 : (/^  [A-Za-z0-9_-]+:/ ? 0 : inj) }
    { buf[NR] = $0; ij[NR] = inj }
    END { for (i = 1; i <= NR; i++) {
        l = buf[i]
        if (ij[i]) {
          if (m == "dropenv" && l ~ /ADS_DL_CACHE:/) continue
          if (m == "dropconsumer" && l ~ /run:.*(install-elan|anscombe-artifacts)\.sh/) continue
          if (l ~ /uses: actions\/cache@v4/) {
            tc = (buf[i+1] buf[i+2] buf[i+3]) ~ /lean-tc-/
            if ((m == "dropcache" && !tc && (buf[i+3] ~ /dl-/)) || (m == "droptc" && tc)) { i += 3; continue }
            if (m == "key" && buf[i+3] ~ /key: dl-/) sub(/key: dl-/, "key: xx-", buf[i+3])
            if (m == "path" && buf[i+2] ~ /\.dl-cache/) sub(/\.dl-cache/, ".dl-cacheX", buf[i+2])
          }
        }
        print buf[i] } }' "$1"
}
n=0
while IFS='|' read -r wf job kind cons xk xp; do
  [ -n "$wf" ] || continue
  w="$root/.github/workflows/$wf"
  bash "$chk" "$w" "$job" "$kind" "$cons" $xk $xp >"$t/wf.out" 2>&1 || { echo "FAIL real $wf $job: $(cat "$t/wf.out")"; exit 1; }
  modes="dropcache dropenv key path dropconsumer"; [ -n "$xk" ] && modes="$modes droptc"
  for mode in $modes; do
    mutate "$w" "$job" "$mode" > "$t/m.yml"
    cmp -s "$w" "$t/m.yml" && { echo "FAIL mutation $mode left $wf $job unchanged (the falsifier is blind)"; exit 1; }
    bash "$chk" "$t/m.yml" "$job" "$kind" "$cons" $xk $xp >/dev/null 2>&1 && { echo "FAIL mutant $mode of $wf $job passed"; exit 1; }
    n=$((n + 1))
  done
done <<< "$JOBS"
echo "falsify-dl-cached: $n workflow mutants all RED"
grep -q 'dl-cached.sh' "$root/scripts/install-elan.sh" || { echo "FAIL install-elan.sh bypasses dl-cached.sh"; exit 1; }
grep -q 'dl-cached.sh' "$root/scripts/fetch-gradle.sh" || { echo "FAIL fetch-gradle.sh bypasses dl-cached.sh"; exit 1; }
grep -q 'distributionSha256Sum' "$root/scripts/fetch-gradle.sh" || { echo "FAIL fetch-gradle.sh lost the sha pin"; exit 1; }
grep -q 'fetch-gradle.sh' "$root/scripts/anscombe-artifacts.sh" || { echo "FAIL anscombe-artifacts.sh uses the wrapper download"; exit 1; }
grep -q 'sha256sum -c' "$root/scripts/dl-cached.sh" || { echo "FAIL dl-cached.sh has no verify"; exit 1; }
[ -x "$root/scripts/falsify-fetch-gradle.sh" ] || { echo "FAIL poisoned-cache falsifier missing"; exit 1; }
grep -q "Fetch.java" "$root/scripts/dl-cached.sh" && [ -f "$root/scripts/Fetch.java" ] || { echo "FAIL curl-free fetch path (Fetch.java) is gone"; exit 1; }
echo "falsify-dl-cached: PASS (real green, no-verify mutant red, ci.yml and scripts wired)"
