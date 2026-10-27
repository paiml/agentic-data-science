#!/bin/zsh
# planted.sh NN OUTDIR : F5 proof - blank tail, mono, wrong output must each FAIL the check (rc=1)
NN=$1; D=${2:A}; S=${0:A:h}; P=$D/planted; mkdir -p $P; V=$D/m1-$NN.mp4
cp $D/final-screen.txt $P/ok-screen.txt; sed 's/ok\./BAD/g; s/rows 344/rows 000/g; s/OK$/FAIL/' $D/final-screen.txt > $P/bad-screen.txt
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 $V)
ffmpeg -v error -y -i $V -vf "fade=t=out:st=$(printf '%.2f' $((DUR-4))):d=0.1:color=black" -t $DUR -c:v libx264 -crf 20 $P/blank-tail.mp4
ffmpeg -v error -y -i $V -vf hue=s=0 -c:v libx264 -crf 20 $P/mono.mp4
ffmpeg -v error -y -i $V -vf "scale=1280:720,pad=1920:1080:0:0" -c:v libx264 -crf 20 $P/small.mp4
r=0
for c in blank-tail:$P/ok-screen.txt mono:$P/ok-screen.txt wrong-output:$P/bad-screen.txt small:$P/ok-screen.txt; do
  n=${c%%:*}; s=${c#*:}; vid=$P/$n.mp4; [ $n = wrong-output ] && vid=$V
  cp $s $P/screen-$n.txt
  mkdir -p $P/t-$n; cp $vid $P/t-$n/m1-$NN.mp4; cp $s $P/t-$n/final-screen.txt
  $S/check.sh $NN $P/t-$n >/dev/null 2>&1 && { echo "planted $n: check PASSED (BAD)"; r=1; } || echo "planted $n: check FAILED as required"
done
exit $r
