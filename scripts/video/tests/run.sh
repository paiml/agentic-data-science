#!/bin/bash
# run.sh [workdir]: build the synthetic takes (gen.sh) and assert every proof. must-PASS takes: VERDICT PASS. must-FAIL takes: VERDICT FAIL
# and each named check FAIL (the others are not asserted, except that the pixel-blind pane classes keep T2post PASS where stated).
# Row: <take>|<layout: yes|no>|<mode: gate|plain>|<PASS or the checks that must FAIL, comma separated>
set -u
HERE=$(cd "$(dirname "$0")" && pwd); W=${1:-$(mktemp -d "${TMPDIR:-/tmp}/vcheck-tests.XXXXXX")}
"$HERE/gen.sh" "$W" >/dev/null || { echo "gen failed"; exit 2; }
V="$HERE/.."
rows=(
 "good-v3|yes|gate|PASS"            "good-x1100|yes|gate|PASS"        "good-beats|yes|gate|PASS"       "good-white|yes|gate|PASS"
 "good-v3|no|plain|PASS"
 "bad-oldfont|yes|gate|font-spacing"            "bad-mosaic|yes|gate|plot-legibility"
 "bad-fit1px|yes|gate|plot-legibility"          "bad-axis50|yes|gate|plot-legibility"      "bad-axis150|yes|gate|plot-legibility"
 "bad-overlap|yes|gate|plot-legibility"         "bad-nofit-white|yes|gate|plot-legibility" "bad-fit-grid|yes|gate|plot-legibility"
 "bad-fit-bg|yes|gate|plot-legibility"          "bad-markers|yes|gate|plot-legibility"
 "bad-smalltext|yes|gate|plot-text"             "bad-lowtitle|yes|gate|plot-text"          "bad-nolegend|yes|gate|plot-text"
 "bad-ticks14|yes|gate|plot-text"               "bad-wm-bl|yes|gate|watermark"             "bad-nocell|yes|gate|cell"
 "bad-nolossless|yes|gate|font-spacing"         "bad-dim|yes|gate|dim-luma"                "bad-revealshift|yes|gate|reveal-shift"
 "bad-fade|yes|gate|hold-fade"                  "bad-pitch24|yes|gate|T3,cell,font-spacing" "bad-prediv|yes|gate|T2pre,box"
 "bad-shift900|yes|gate|T2post,pane-edge"       "bad-n7|yes|gate|pane-edge"                "bad-o3-border3|yes|gate|pane-edge"
 "bad-o1-step4|no|plain|T2post"                 "bad-o2-hue|no|plain|T2post"               "bad-o5-div1|no|plain|T2post"
 "bad-o6-div2|no|plain|T2post"                  "bad-gutter50|no|plain|T2post"
 "good-v3|no|gate|pane-edge"                    "bad-o5-div1|no|gate|T2post,pane-edge"
 "bad-nohold|yes|gate|frozen"                   "bad-fmt|yes|gate|input"
 "bad-freeze|yes|gate|frozen"                   "bad-shorthold|yes|gate|frozen"
 "bad-beats|yes|gate|beats"                     "bad-beats-aviz|yes|gate|beats"            "bad-beats-table|yes|gate|beats"
 "bad-beats-tree|yes|gate|beats"                "bad-beats-version|yes|gate|beats"         "bad-beats-call|yes|gate|beats"
 "bad-beats-unit|yes|gate|beats"                "bad-beats-subset|yes|gate|beats"          "bad-beats-nokey|yes|gate|sidecar,beats"
 "bad-beats-short|yes|gate|beats"               "bad-beats-outside|yes|gate|beats"         "bad-beats-overlap|yes|gate|beats"
 "bad-beats-long|yes|gate|beats"                "bad-beats-use|yes|gate|beats"             "bad-beats-build|yes|gate|beats"
 "bad-beats-moving|yes|gate|beats"
 "good-real|yes|gate|PASS"                      "bad-still-outside|yes|gate|frozen"        "bad-real-short|yes|gate|beats"
 "bad-wm-code|yes|gate|watermark"               "bad-wm-low|yes|gate|watermark"
 "bad-garbage|no|gate|core,T3,T2pre,box,T2post,input"
)
# Proofs run in parallel (JOBS at a time, default 12) with CORE_FPS=2: the pixel core samples 2 fps here (real takes: 20 fps, vcheck default).
export CORE_FPS=${CORE_FPS:-2}; J=${JOBS:-12}
throttle(){ while [ "$(jobs -r | wc -l)" -ge "$J" ]; do wait -n; done; }
pass=0; bad=0
for r in "${rows[@]}"; do IFS='|' read -r take lay mode want <<<"$r"
  args=("$W/$take.mp4"); [ $lay = yes ] && args+=("$W/$take.layout"); [ $mode = gate ] && args+=(--gate); [ $lay = no ] && args+=(--shown 18.5)
  throttle; ( "$V/vcheck.sh" "${args[@]}" > "$W/out.$take.$lay.$mode" 2>&1 ) &
done
# false-pass guards: under --gate every sidecar field a check needs, missing or empty, is FAIL on the otherwise-good take
keys=(cell_w cell_h shown_s plot_pane_left_px rect.code rect.plot rect.axes rect.title rect.legend rect.ticks rect.watermark fit_rgb axis_x axis_x_data axis_y axis_y_data tick_px beats)
for k in "${keys[@]}"; do for how in missing empty; do
  if [ $how = missing ]; then grep -v "^${k//./\\.}=" "$W/good-v3.layout" > "$W/g-$k-$how.layout"; else sed "s/^${k//./\\.}=.*/$k=/" "$W/good-v3.layout" > "$W/g-$k-$how.layout"; fi
  throttle; ( "$V/vcheck.sh" "$W/good-v3.mp4" "$W/g-$k-$how.layout" --gate --sidecar-only > "$W/out.g-$k-$how" 2>&1 ) &
done; done
# an empty pixel-core result is not a pass
throttle; ( VCHECK_CORE=/bin/true "$V/vcheck.sh" "$W/good-v3.mp4" "$W/good-v3.layout" --gate > "$W/out.emptycore" 2>&1 ) &
# --sidecar-only with no layout, or a layout path that does not exist, is not a pass
throttle; ( "$V/vcheck.sh" "$W/good-v3.mp4" --sidecar-only > "$W/out.so-nolayout" 2>&1 ) &
throttle; ( "$V/vcheck.sh" "$W/good-v3.mp4" "$W/does-not-exist.layout" --sidecar-only > "$W/out.so-missing" 2>&1 ) &
# malformed sidecar values must fail in the sidecar check itself (also under --sidecar-only), never skip a check
mal(){ local n=$1 k=$2 v=$3; sed "s/^${k//./\\.}=.*/$k=$v/" "$W/good-v3.layout" > "$W/m-$n.layout"; throttle; ( "$V/vcheck.sh" "$W/good-v3.mp4" "$W/m-$n.layout" --gate --sidecar-only > "$W/out.m-$n" 2>&1 ) & }
mal fit fit_rgb '#ffd700'; mal fitz fit_rgb zzzzzz; mal fit5 fit_rgb ffd70; mal dot shown_s .; mal dots axis_x_data 1.2.3,4; mal bnum beats 'a:1-2'; mal bwin beat.tree 4.6; mal bwin2 beat.tree '.,.'; mal pl plot_pane_left_px 12x; mal rect rect.code 'a,b,c,d'; mal axis axis_x_data 'x,y'; mal tick tick_px 2x
# lab.sh (the nightly runner) has its own proofs: no takes, a take without its sidecar, a bad take, a good take
mkdir -p "$W/lab-empty" "$W/lab-nosidecar" "$W/lab-bad" "$W/lab-good"; cp "$W/good-v3.mp4" "$W/lab-nosidecar/t.mp4"
for f in bad-oldfont good-v3; do d=lab-bad; [ $f = good-v3 ] && d=lab-good
  cp "$W/$f.mp4" "$W/$f.mp4.frame.png" "$W/$d/"; cp "$W/$f.layout" "$W/$d/$f.mp4.layout"; cp -r "$W/$f.layout.beats" "$W/$d/$f.mp4.layout.beats"; done
cp "$W/good-v3.mp4" "$W/lab-good/good-v3.base.mp4"                      # compose's intermediate has no sidecar and is not a take
printf '#!/bin/bash\necho "boom: helper build failed"; exit 2\n' > "$W/stub-vcheck.sh"; chmod +x "$W/stub-vcheck.sh"; mkdir -p "$W/lab-stub"; cp "$W/good-v3.mp4" "$W/lab-stub/t.mp4"; touch "$W/lab-stub/t.mp4.layout"
throttle; ( "$V/lab.sh" > "$W/out.lab-noarg" 2>&1; echo "rc=$?" >> "$W/out.lab-noarg" ) &
throttle; ( "$V/lab.sh" "" > "$W/out.lab-emptyarg" 2>&1; echo "rc=$?" >> "$W/out.lab-emptyarg" ) &
throttle; ( LAB_VCHECK="$W/stub-vcheck.sh" "$V/lab.sh" "$W/lab-stub" > "$W/out.lab-stub" 2>&1; echo "rc=$?" >> "$W/out.lab-stub" ) &
for d in lab-empty lab-nosidecar lab-bad lab-good; do throttle; ( "$V/lab.sh" "$W/$d" > "$W/out.$d" 2>&1; echo "rc=$?" >> "$W/out.$d" ) & done
wait
for r in "${rows[@]}"; do IFS='|' read -r take lay mode want <<<"$r"; out=$(cat "$W/out.$take.$lay.$mode"); ok=1
  if [ "$want" = PASS ]; then echo "$out" | grep -q '^VERDICT PASS' || ok=0
  else echo "$out" | grep -q '^VERDICT FAIL' || ok=0; for c in ${want//,/ }; do echo "$out" | grep -q "^CHECK $c FAIL" || ok=0; done; fi
  if [ $ok = 1 ]; then pass=$((pass+1)); echo "ok   $take ($lay,$mode) -> $want"; else bad=$((bad+1)); echo "FAIL $take ($lay,$mode) wanted $want"; echo "$out" | sed 's/^/     /' | cut -c1-260; fi
done
# the guard messages name the cause (a fail for the wrong reason is not a proof)
says(){ local take=$1 pat=$2; local out; out=$(cat "$W/out.$take.yes.gate")
  if echo "$out" | grep -q "$pat"; then pass=$((pass+1)); echo "ok   $take says '$pat'"; else bad=$((bad+1)); echo "FAIL $take must say '$pat'"; echo "$out" | grep FAIL | cut -c1-260; fi; }
says bad-fit-grid "too close to the grid colour"; says bad-fit-bg "too close to the background"; says bad-markers "fit is not one line"
says bad-axis150 "clipped"; says bad-lowtitle "title ink top"; says bad-nolegend "no fit swatch"; says bad-ticks14 "tick_px=14"
says bad-beats "unexplained dependency 'serde_json'"; says bad-beats-aviz "no 'aprender'"; says bad-beats-table "unexplained dependency 'serde_json'"
says bad-still-outside "outside the declared beat windows"; says bad-real-short "not 4..8 s"
says bad-beats-short "not 4..8 s"; says bad-beats-moving "does not hold"; says bad-beats-overlap "before the previous beat"; says bad-beats-long "not 4..8 s"; says bad-beats-use "no visible aprender call"; says bad-beats-build "no number with a unit"
for k in "${keys[@]}"; do for how in missing empty; do out=$(cat "$W/out.g-$k-$how")
  if echo "$out" | grep -q '^VERDICT FAIL' && echo "$out" | grep -q "^CHECK sidecar FAIL.* $k"; then pass=$((pass+1)); echo "ok   sidecar $how $k -> FAIL"; else bad=$((bad+1)); echo "FAIL sidecar $how $k must FAIL"; fi; done; done
for n in so-nolayout so-missing; do out=$(cat "$W/out.$n")
  if echo "$out" | grep -q '^VERDICT FAIL' && echo "$out" | grep -q '^CHECK sidecar FAIL'; then pass=$((pass+1)); echo "ok   --sidecar-only $n -> FAIL"; else bad=$((bad+1)); echo "FAIL --sidecar-only $n must FAIL"; echo "$out" | cut -c1-200; fi; done
for n in fit fitz fit5 dot dots bnum bwin bwin2 pl rect axis tick; do out=$(cat "$W/out.m-$n")
  if echo "$out" | grep -q '^VERDICT FAIL' && echo "$out" | grep -q '^CHECK sidecar FAIL'; then pass=$((pass+1)); echo "ok   malformed $n -> FAIL"; else bad=$((bad+1)); echo "FAIL malformed $n must FAIL"; echo "$out" | cut -c1-200; fi; done
out=$(cat "$W/out.emptycore")
if echo "$out" | grep -q '^VERDICT FAIL' && echo "$out" | grep -q '^CHECK core FAIL'; then pass=$((pass+1)); echo "ok   empty core -> FAIL"; else bad=$((bad+1)); echo "FAIL empty core must FAIL"; fi
for c in "lab-empty|1" "lab-nosidecar|1" "lab-bad|1" "lab-good|0" "lab-noarg|1" "lab-emptyarg|1" "lab-stub|1"; do IFS='|' read -r d want <<<"$c"; rc=$(sed -n 's/^rc=//p' "$W/out.$d")
  if [ "$rc" = "$want" ]; then pass=$((pass+1)); echo "ok   lab.sh $d -> rc $rc"; else bad=$((bad+1)); echo "FAIL lab.sh $d rc ${rc:-?} wanted $want"; sed 's/^/     /' "$W/out.$d" | cut -c1-200 | tail -5; fi; done
grep -q 'takes: 1, failed: 0' "$W/out.lab-good" && { pass=$((pass+1)); echo "ok   lab.sh skips *.base.mp4"; } || { bad=$((bad+1)); echo "FAIL lab.sh counted a .base.mp4"; }
grep -q 'boom' "$W/out.lab-stub" && { pass=$((pass+1)); echo "ok   lab.sh prints a vcheck error without CHECK lines"; } || { bad=$((bad+1)); echo "FAIL lab.sh swallowed a vcheck error"; }
grep -q 'not_measured' "$W/out.lab-noarg" && grep -q 'not_measured' "$W/out.lab-emptyarg" && { pass=$((pass+1)); echo "ok   lab.sh without a takes dir is not_measured (no ./recordings fallback)"; } || { bad=$((bad+1)); echo "FAIL lab.sh fallback"; }
# video-lab.yml re-enable window reads the marker on ANY ticket, open or closed; static check of the workflow text
if grep -q 'issue list --label video-lab --state all .*video-lab:disabled' "$HERE/../../../.github/workflows/video-lab.yml"; then pass=$((pass+1)); echo "ok   video-lab.yml marker query uses --state all"; else bad=$((bad+1)); echo "FAIL video-lab.yml marker query must use --state all"; fi
echo "proofs: $pass ok, $bad wrong"; [ $bad = 0 ]
