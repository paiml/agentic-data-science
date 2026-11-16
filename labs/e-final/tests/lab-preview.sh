#!/usr/bin/env bash
# lab-preview.sh COURSE LAB : RMV-001 v0.9.9 §15.6 + D48 local lab preview. Builds the lab image from labs/<LAB>/image/Dockerfile at commit C,
# starts it (127.0.0.1:PORT -> code-server :8080, the Coursera lab front end), waits for /healthz, grades in fresh
# containers (starter fails, solution passes, a planted wrong answer fails readably), compares the parity table with
# preview/coursera-lab.json, and writes <OUT>/<COURSE>/<LAB>/card.{json,md}. A value Coursera has not given us is NOT MEASURED,
# never green. Exit 0 = card written and nothing red; 1 = a red row; 2 = could not measure (no docker, dirty image inputs, checked before any build); 3 = grading skipped (SKIP_GRADE=1): verdict SKIPPED, never GREEN.
# Spec: RMV-001 v0.9.9. Env: IMAGE_DIR/COURSERA_JSON/SOLUTION_DIR override inputs (falsifiers only), PORT (default 18080), OUT (default out/lab-preview), KEEP=1 leaves the container running, SKIP_GRADE=1 skips grading.
set -uo pipefail
COURSE=${1:?course (c05)}; LAB=${2:?lab id (e-final)}
here=$(cd "$(dirname "$0")" && pwd); lab=$(cd "$here/.." && pwd); repo=$(cd "$lab/../.." && pwd)
[ "$(basename "$lab")" = "$LAB" ] || { echo "NOT MEASURED: LAB=$LAB is not $(basename "$lab")"; exit 2; }
PORT=${PORT:-18080}; OUT=${OUT:-$repo/out/lab-preview}/$COURSE/$LAB; mkdir -p "$OUT"
command -v docker >/dev/null || { echo "NOT MEASURED: no docker"; exit 2; }
C=$(git -C "$repo" rev-parse --short=12 HEAD)
dirty=$(git -C "$repo" status --porcelain -- "labs/$LAB/image" | wc -l)
[ "$dirty" -eq 0 ] || [ -n "${IMAGE_DIR:-}" ] || { echo "NOT MEASURED: image inputs dirty ($dirty paths under labs/$LAB/image); commit them first"; exit 2; }
tag="ads-lean-lab:c-$C"; [ "$dirty" -eq 0 ] || tag="$tag-dirty"; [ -z "${IMAGE_DIR:-}" ] || tag="$tag-variant"
T0=$(date +%s.%N)
bt0=$(date +%s)
docker build -q --platform linux/amd64 -t "$tag" "${IMAGE_DIR:-$lab/image}" >/dev/null || { echo "FAIL: docker build"; exit 1; }
bsec=$(( $(date +%s) - bt0 ))
digest=$(bash "$(dirname "$0")/image-digest.sh" "$tag") || { echo "NOT MEASURED: image digest"; exit 2; }
name="lab-preview-$COURSE-$LAB"; docker rm -f "$name" >/dev/null 2>&1
CPUS=${CPUS:-}; MEM=${MEM:-}
docker run -d --rm --name "$name" --platform linux/amd64 -p "127.0.0.1:$PORT:8080" ${CPUS:+--cpus "$CPUS"} ${MEM:+--memory "$MEM"} "$tag" >/dev/null \
  || { echo "FAIL: docker run"; exit 1; }
[ "${KEEP:-0}" = 1 ] || trap 'docker rm -f "$name" >/dev/null 2>&1' EXIT
ready=NO; for i in $(seq 1 120); do
  curl -fsS -o /dev/null "http://127.0.0.1:$PORT/healthz" 2>/dev/null && { ready=YES; break; }; sleep 0.5; done
rsec=$(echo "$(date +%s.%N) - $T0" | bc)
[ "$ready" = YES ] && echo "READY http://127.0.0.1:$PORT/ in ${rsec}s (image $tag $digest)" || echo "NOT READY after 60 s"
# ---- parity: local (measured from the running container) vs Coursera (preview/coursera-lab.json, from a live read-only export)
insp() { docker inspect "$name" --format "$1" 2>/dev/null; }
declare -A L; L[image_digest]=$digest; L[uid]=$(docker exec "$name" id -u coder 2>/dev/null); L[workdir]=$(insp '{{.Config.WorkingDir}}')
L[http_port]=$(jq -r '.httpPort' "$lab/image/manifest.json"); L[network]=$(insp '{{.HostConfig.NetworkMode}}')
L[cpus]=$(insp '{{.HostConfig.NanoCpus}}' | awk '{print ($1==0)?"unlimited":$1/1e9}'); L[mem_mb]=$(insp '{{.HostConfig.Memory}}' | awk '{print ($1==0)?"unlimited":$1/1048576}')
L[session_timeout_min]=none
cj=${COURSERA_JSON:-$lab/preview/coursera-lab.json}; red=0; rows=""
for k in image_digest cpus mem_mb session_timeout_min network uid workdir http_port; do
  lv=${L[$k]:-?}; cv=NOT_MEASURED; [ -s "$cj" ] && cv=$(jq -r --arg k "$k" '.[$k] // "NOT_MEASURED"' "$cj")
  if [ "$cv" = NOT_MEASURED ]; then st=not-measured; elif [ "$cv" = "$lv" ]; then st=match; else st=RED; red=$((red+1)); fi
  rows="$rows$k\t$lv\t$cv\t$st\n"
done
# ---- grader receipt: fresh unprivileged containers, network none (as Coursera), like image-test.sh
g() { docker run --rm --network none --entrypoint "" --user coder -e HOME=/home/coder -v "$repo:/work:ro" "$tag" bash /work/labs/$LAB/tests/run.sh "$1"; }
grows=""; gbad=0
gr() { # name want dir
  local t0 rc t1; t0=$(date +%s.%N); g "$3" >"$OUT/grade-$1.out" 2>&1; rc=$?; t1=$(date +%s.%N)
  local v=PASS; [ "$rc" -eq "$2" ] || { v=FAIL; gbad=$((gbad+1)); }
  grows="$grows$1\t$2\t$rc\t$(printf '%.1f' "$(echo "$t1 - $t0" | bc)")\t$v\t$( { grep -E "^FAIL" "$OUT/grade-$1.out" | head -n 1 || true; } | grep . || echo "$(grep -c '^PASS' "$OUT/grade-$1.out") PASS lines, no FAIL" )\n"; }
if [ "${SKIP_GRADE:-0}" != 1 ]; then
  W=$(mktemp -d "$repo/.lab-preview-XXXXXX"); trap 'rm -rf "$W"; docker rm -f "$name" >/dev/null 2>&1' EXIT
  mkdir -p "$W/wrong"; sed 's/\bsorry\b/rfl/' "$lab/starter/Mean.lean" > "$W/wrong/Mean.lean"; chmod -R a+rX "$W"
  gr starter 1 /work/labs/$LAB/starter
  gr solution 0 "/work/${SOLUTION_DIR:-labs/$LAB/solution}"
  gr planted-wrong-answer 1 "/work/$(basename "$W")/wrong"
  # README step 4, verbatim: `lean Mean.lean` in the project folder. Solution: clean (rc 0, no output). Starter: "declaration uses `sorry`".
  rs() { # name want dir grep
    local t0 rc t1 v=PASS; t0=$(date +%s.%N)
    docker run --rm --network none --entrypoint "" --user coder -e HOME=/home/coder -v "$repo:/work:ro" "$tag" bash -c 'export PATH=$HOME/.elan/bin:$PATH; mkdir /tmp/p && cp "$1"/Mean.lean /tmp/p && cd /tmp/p && lean Mean.lean' x "$3" >"$OUT/readme-$1.out" 2>&1; rc=$?; t1=$(date +%s.%N)
    [ "$rc" -eq "$2" ] || v=FAIL; if [ -n "$4" ]; then grep -q "$4" "$OUT/readme-$1.out" || v=FAIL; else [ ! -s "$OUT/readme-$1.out" ] || v=FAIL; fi
    [ "$v" = PASS ] || gbad=$((gbad+1))
    grows="$grows$1\t$2\t$rc\t$(printf '%.1f' "$(echo "$t1 - $t0" | bc)")\t$v\t$(head -n 1 "$OUT/readme-$1.out" | cut -c1-100)\n"; }
  rs readme-4-solution 0 "/work/${SOLUTION_DIR:-labs/$LAB/solution}" ""
  rs readme-4-starter 0 /work/labs/$LAB/starter "declaration uses"
fi
# ---- card
nm=$(printf "$rows" | grep -c 'not-measured')
verdict=GREEN; [ "$nm" -eq 0 ] || verdict=AMBER; [ "${SKIP_GRADE:-0}" != 1 ] || verdict=SKIPPED; [ "$ready" = YES ] || verdict=RED; [ "$red" -eq 0 ] || verdict=RED; [ "$gbad" -eq 0 ] || verdict=RED
{ echo "# $COURSE / $LAB local lab preview (RMV-001 v0.9.9)"; echo; echo "- verdict: **$verdict** ($nm parity rows NOT MEASURED; AMBER = previewable, parity not proven)"
  echo "- commit C: $C (image inputs dirty: $dirty)"; echo "- image: \`$tag\` digest \`$digest\` (build $bsec s)"
  echo "- open: http://127.0.0.1:$PORT/ ready=$ready in ${rsec}s"; echo; echo "## Parity vs Coursera"; echo "| key | local | coursera | status |"; echo "|---|---|---|---|"
  printf "$rows" | awk -F'\t' '{printf "| %s | %s | %s | %s |\n",$1,$2,$3,$4}'; echo; echo "## Grader receipt (in-container, network none)"; echo "| run | want | got | s | verdict | first line |"; echo "|---|---|---|---|---|---|"
  printf "$grows" | awk -F'\t' '{printf "| %s | %s | %s | %s | %s | %s |\n",$1,$2,$3,$4,$5,$6}'; } > "$OUT/card.md"
jq -n --arg v "$verdict" --arg c "$C" --arg tag "$tag" --arg d "$digest" --arg ready "$ready" --arg rsec "$rsec" --arg port "$PORT" --argjson dirty "$dirty" \
  --arg rows "$(printf "$rows")" --arg g "$(printf "$grows")" '{verdict:$v,commit:$c,image:$tag,digest:$d,ready:$ready,ready_seconds:($rsec|tonumber),url:("http://127.0.0.1:"+$port+"/"),inputs_dirty:$dirty,parity_tsv:$rows,grader_tsv:$g}' > "$OUT/card.json"
cat "$OUT/card.md"
case "$verdict" in RED) exit 1;; SKIPPED) echo "SKIPPED: grading not run (SKIP_GRADE=1), exit 3, not a pass"; exit 3;; esac
