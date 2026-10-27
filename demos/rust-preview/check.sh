#!/bin/zsh
# check.sh NN OUTDIR : frame-check + F7 delivered height; regexes per scene = teleprompter output
NN=$1; D=${2:A}; S=${0:A:h}
case $NN in
 01) RX=('contract: ads-rust-p1-v1 rows 344 -> 342 OK' 'rows loaded: 344' 'rows kept:   342' '\$ cargo run --manifest-path rust/ads-rust/Cargo.toml --example a-m1-p1$');;
 02) RX=('contract: ads-rust-p1-v1 max .diff. = .* OK');;
 03) RX=('test result: ok\. 6 passed' '\$ cargo test --manifest-path rust/ads-rust/Cargo.toml --test p1$');;
 04) RX=('\$ jq \. datasets/golden/p1.json \| head -28' '"mean"');;
  05) RX=('metadata:' 'version');;
 06) RX=('\$ head -4 datasets/penguins/penguins.csv' 'Adelie');;
  07) RX=('^shacl OK');;
 08) RX=('^pmat OK');;
 09) RX=('rust gate OK');;
 10) RX=('rust gate OK' '^pmat OK');;
esac
$S/frame-check.sh $D/m1-$NN.mp4 $D/final-screen.txt 36 $RX > $D/check.txt 2>&1; rc=$?
H=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 $D/m1-$NN.mp4)
[ "$H" = 1080 ] && echo "ok F7 delivered height $H" >> $D/check.txt || { echo "F7 height $H != 1080" >> $D/check.txt; rc=1; }
echo "$NN rc=$rc"; exit $rc
