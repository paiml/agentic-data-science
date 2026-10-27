#!/bin/zsh
W=${PV_ROOT:?set PV_ROOT}; cd $W
for n in "$@"; do
  nice -n 10 flock .lock scripts/rec-rust-m1.sh $n out/m1-$n > out/m1-$n.rec.log 2>&1; rr=$?
  [ $rr = 0 ] && { scripts/check.sh $n out/m1-$n >> out/batch.log; } || echo "$n REC rc=$rr $(tail -n1 out/m1-$n.rec.log)" >> out/batch.log
done
echo batch-done >> out/batch.log
