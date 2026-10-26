#!/bin/bash
# vcheck-core.sh <video 1920x1080 20fps> <plot_shown_s> [ss] [dur]  -> per-frame lines to stdout, SUMMARY last.
# Pixel core of vcheck (T3 line pitch >= 28, T2pre no divider before shown, box, T2post plot edge >= 1056 from shown+0.25 s).
# Derived from vcheck-rust-r3 (sha 572bf31e) + the xl thin-divider term.
# The edge helper is edge.c next to this file; the pane edge from the recorder's layout sidecar is checked in vcheck.sh.
set -o pipefail
v=$1; shown=$2; ss=${3:-0}; dur=${4:-1000}
F=${CORE_FPS:-20}   # sampling rate: the recorded 20 fps for real takes; the proofs may sample slower (CORE_FPS=4) to stay fast. Frame time = index / F.
HERE=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/vchk.XXXXXX")
trap 'rm -rf "${tmp:?}"' EXIT
gcc -O2 -o $tmp/edge3 "$HERE/edge.c" || { echo "edge build failed"; exit 2; }
ffmpeg -v error -ss $ss -t $dur -i "$v" -vf "fps=$F,crop=1000:1080:0:0,format=gray,scale=1:1080:flags=area" -f rawvideo - | od -An -v -tu1 -w1080 > $tmp/rows.txt || { echo "vcheck-core: ffmpeg failed (rows)" >&2; exit 3; }
ffmpeg -v error -ss $ss -t $dur -i "$v" -filter_complex "[0:v]fps=$F,crop=1920:700:0:0,format=gray,split=3[a][b][c];[a]scale=1920:1:flags=area[m1];[b]geq=lum='min(255,8*abs(lum(X,Y)-lum(X,min(Y+1,699))))':cb=128:cr=128,scale=1920:1:flags=area[m2];[c]geq=lum='min(255,8*abs(lum(X,Y)-lum(min(X+1,1919),Y)))':cb=128:cr=128,scale=1920:1:flags=area[m3];[m1][m2][m3]hstack=inputs=3" -f rawvideo - | od -An -v -tu1 -w5760 > $tmp/cols.txt || { echo "vcheck-core: ffmpeg failed (cols)" >&2; exit 3; }
ffmpeg -v error -ss $ss -t $dur -i "$v" -vf fps=$F -f rawvideo -pix_fmt rgb24 - | $tmp/edge3 > $tmp/edge.txt || { echo "vcheck-core: ffmpeg or edge helper failed" >&2; exit 3; }
paste -d'|' $tmp/rows.txt $tmp/cols.txt $tmp/edge.txt | awk -F'|' -v shown=$shown -v F=$F '
{ n=split($1,p," "); for(y=1;y<=n;y++) P[y]=p[y]+0
  # pitch: autocorr over rows 1..812
  N=812; mean=0; for(y=1;y<=N;y++) mean+=P[y]; mean/=N
  c0=0; for(y=1;y<=N;y++){d=P[y]-mean; c0+=d*d}
  best=0; bl=0
  for(L=14;L<=60;L++){ c=0; for(y=1;y+L<=N;y++) c+=(P[y]-mean)*(P[y+L]-mean); c/= (c0>0?c0:1); R[L]=c; if(c>best){best=c;bl=L} }
  pitch=0; if(c0>1){ for(L=14;L<=60;L++) if(R[L]>=0.85*best && R[L]>=R[L-1] && R[L]>=R[L+1]){pitch=L;break} }
  m=split($2,q," "); div=0; xp=0
  for(x=1;x<=1920;x++){ m1=q[x]+0; m2=q[1920+x]+0; var=m2; M1[x]=m1; V[x]=var; G[x]=q[3840+x]+0 }
  split($3,E," "); div=E[8]+0   # divider: full-height thin line from the edge helper (divx)
  empty=0; if(div>0 && (NR-1)/F<shown){ e=0; for(x=div+4;x<=1920;x++) if(M1[x]<45&&V[x]<1.5) e++; if(1920-div-4>=192 && e>=0.9*(1920-div-4)) empty=1 }
  t=(NR-1)/F
  split($3,E," "); xpl=E[1]+0
  h_t3=(c0>1 && pitch<28); h_div=(t<shown && div>0); h_box=empty; h_w=(t>=shown+0.25 && (xpl==0 || xpl<1056))
  hit=(h_t3||h_div||h_box||h_w)
  printf "%.2f pitch=%d div=%d plotx=%d xb=%d xi=%d T3=%d T2pre=%d box=%d T2post=%d %s\n", t, pitch, div, xpl, E[2]+0, E[3]+0, h_t3, h_div, h_box, h_w, (hit?"HIT":"ok")
  tot++; if(h_t3)A3++; if(h_div)B2++; if(h_box)CB++; if(h_w)D2++
  if(pitch>0 && (mn==0||pitch<mn)) mn=pitch
}
END{ printf "SUMMARY frames=%d min_pitch=%d T3_hits=%d T2pre_hits=%d box_hits=%d T2post_hits=%d\n", tot, mn, A3, B2, CB, D2 }'
