#!/bin/zsh
# usage: rec-rust-m1.sh NN OUTDIR   Rust M1 lesson NN (01..10), v2 (quorum CHANGES 1-10). 100x36 cells at 16x28 px.
NN=${1:?nn}; D=${2:?outdir}; mkdir -p $D; D=${D:A}
W=${PV_ROOT:?set PV_ROOT}; S=$W/scripts; P=/tmp/ads-pv
export PV_REPO=$P PV_TARGET=$P/target PV_TMP=$D
export PATH=$HOME/.cargo/bin:$HOME/.local/bin:$PATH
export RUSTUP_TOOLCHAIN=1.99.1 CARGO_TARGET_DIR=$PV_TARGET
M=rust/ads-rust; BH=12; WAIT=120; TALL=0
case $NN in
 01) SRC=$M/examples/a-m1-p1/main.rs; TK=(7 10 14 17); CMD="cargo run --manifest-path $M/Cargo.toml --example a-m1-p1"; EXP='contract: ads-rust-p1-v1 rows 344 -> 342 OK';;
 02) SRC=$M/examples/a-m1-p1-profile/main.rs; TK=(9 19 28 30); CMD="cargo run --manifest-path $M/Cargo.toml --example a-m1-p1-profile"; EXP='contract: ads-rust-p1-v1 max .diff. = .* OK'; TALL=30;;
 03) SRC=$M/tests/p1.rs; TK=(12 22 31 40); CMD="cargo test --manifest-path $M/Cargo.toml --test p1"; EXP="test result: ok"; TALL=22;;
 04) SRC=datasets/golden/p1.json; TK=(1 2 3 4); CMD='jq . datasets/golden/p1.json | head -28'; EXP='"mean"'; TALL=31;;
 05) SRC=contracts/ads-rust-p1-v1.yaml; TK=(1 2 3 4); CMD='head -28 contracts/ads-rust-p1-v1.yaml'; EXP='metadata'; TALL=31; WAIT=15;;
 06) SRC=datasets/penguins/penguins.csv; TK=(1 2 3 4); CMD='head -4 datasets/penguins/penguins.csv'; EXP='Adelie'; WAIT=15;;
 07) SRC=scripts/shacl.sh; TK=(2 8 12 17); CMD='make gate-shacl'; EXP='^shacl OK'; WAIT=300;;
 08) SRC=scripts/gate-pmat.sh; TK=(1 11 12 14); CMD='make gate-rust >/dev/null 2>&1 ; make gate-pmat'; EXP='^pmat OK|pmat FAIL'; WAIT=1500;;
 09) SRC=scripts/gate-rust.sh; TK=(6 7 9 10); CMD='make gate-rust'; EXP='rust gate OK'; WAIT=1500;;
 10) SRC=scripts/gate-rust.sh; TK=(1 5 9 14); CMD='make gate-datasets gate-shacl gate-rust gate-pmat'; EXP='^pmat OK'; WAIT=1200;;
 *) echo "no scene $NN"; exit 2;;
esac
SES=pvrust$NN; R=$D/rec.termctrl; t(){ tmux -L $SES "$@"; }
cd $P || exit 1
# pre-warm off camera (defect 3): run twice, the second run must show no Compiling line
( cd $P && eval "$CMD" ) > $D/warm1.log 2>&1
( cd $P && eval "$CMD" ) > $D/warm2.log 2>&1
grep Compiling $D/warm2.log | grep -qv "Compiling ads-rust v" && { echo "ABORT: Compiling still on warm run"; exit 3; }
rm -f "${R:?}"; termctrl stop $SES >/dev/null 2>&1; t kill-server >/dev/null 2>&1
t -f $S/tmux.conf new-session -d -x 100 -y 36 -c $P "vim -u $S/vimrc.demo -i NONE -N --cmd 'let g:ticks=[${(j:,:)TK}]' $SRC" || exit 1
t split-window -v -l $BH -c $P "$S/bottom.sh"
t select-pane -t 0
sleep 4
termctrl start $SES --cols 100 --rows 36 --cell-width 16 --cell-height 28 --cwd $P --color always --record $R -- env TERM=xterm-256color COLORTERM=truecolor tmux -L $SES attach || exit 1
sleep 0.6
k(){ termctrl send $SES "text:$1"; }
termctrl mark $SES walk
sleep 3.2; i=0; for l in $TK; do i=$((i+1)); k ,$i; sleep 2.5; done
k ,0
[ $TALL -gt 0 ] && t resize-pane -t 1 -y $TALL
termctrl mark $SES run
sleep 0.5
for ((i=1;i<=$#CMD;i++)); do t send-keys -t 1 -l "${CMD[i]}"; sleep 0.06; done; sleep 0.5; t send-keys -t 1 Enter
ok=0; for w in $(seq 1 $WAIT); do sleep 1; t capture-pane -p -t 1 | grep -qE "$EXP" && { ok=1; break; }; done
[ $ok = 1 ] || { echo "ABORT: wait timeout"; termctrl stop $SES >/dev/null 2>&1; t kill-server >/dev/null 2>&1; exit 4; }
sleep 3
termctrl mark $SES final; sleep 3.5
termctrl show $SES > $D/final-screen.txt; termctrl stop $SES
t kill-server >/dev/null 2>&1
termctrl video $R -o $D/base.mp4 --tail-ms 0 >/dev/null 2>&1
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 $D/base.mp4)
ffmpeg -v error -y -i $D/base.mp4 -t $(printf "%.2f" $((DUR-0.25))) -vf "scale=-2:1080,pad=1920:1080:(ow-iw)/2:0:0x1c1c1c,format=yuv420p" -r 20 -c:v libx264 -crf 18 $D/m1-$NN.mp4
echo done
