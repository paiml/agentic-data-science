// glyph: font-spacing measure. stdin = gray8 frame W*H; args: W H x0 y0 x1 y1 (code region).
// ink = deviation from the region's dominant grey >= 50% of the 99.5th-percentile deviation (50% coverage; feed an unscaled
// LOSSLESS frame: JPEG/H.264 ringing widens ink). Text bands = runs of ink rows; the x-height zone of a band = rows with
// >= 50% of the band's peak row ink. ink width = median width of isolated ink runs (< pitch) over the x-height zone of all bands;
// pitch = horizontal autocorrelation peak of the x-height column profile (the cell width); line = median band top-to-top.
// dim = the dimmest fifth of the text bands: their median peak deviation as % of the brightest band (dim luma >= 55% of lit).
// Prints: pitch=<px> ink=<px> ratio=<pitch/ink> line=<px> xh=<px> lp_xh=<line/xh> bands=<n> runs=<n> dim=<pct>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static int cmp(const void*a,const void*b){ return *(const int*)a-*(const int*)b; }
int main(int argc,char**argv){
  if(argc<7) return 2;
  int W=atoi(argv[1]),H=atoi(argv[2]),x0=atoi(argv[3]),y0=atoi(argv[4]),x1=atoi(argv[5]),y1=atoi(argv[6]);
  if(x1>W) x1=W;
  if(y1>H) y1=H;
  unsigned char*g=malloc((size_t)W*H); if(fread(g,1,(size_t)W*H,stdin)!=(size_t)W*H) return 2;
  long hist[256]={0}; for(int y=y0;y<y1;y++) for(int x=x0;x<x1;x++) hist[g[y*W+x]]++;
  int bg=0; for(int i=0;i<256;i++) if(hist[i]>hist[bg]) bg=i;
  long dh[256]={0}, n=0; for(int y=y0;y<y1;y++) for(int x=x0;x<x1;x++){ dh[abs(g[y*W+x]-bg)]++; n++; }
  long acc=0; int fgmax=0; for(int d=255;d>=0;d--){ acc+=dh[d]; if(acc>=n*5/1000){ fgmax=d; break; } }
  if(fgmax<30){ printf("pitch=0 ink=0 ratio=0 line=0 xh=0 lp_xh=0 bands=0 runs=0 dim=0\n"); return 0; }
  int thr=(fgmax+1)/2;
  static int rp[4096]; for(int y=y0;y<y1;y++){ int c=0; for(int x=x0;x<x1;x++) if(abs(g[y*W+x]-bg)>=thr) c++; rp[y]=c; }
  static int bt[512],bb[512],xz0[512],xz1[512]; int nb=0;
  for(int y=y0;y<y1;){ if(!rp[y]){y++;continue;} int s=y; while(y<y1&&rp[y]) y++; if(y-s>=6&&nb<512){ bt[nb]=s; bb[nb]=y; nb++; } }
  static long cp[4096]; memset(cp,0,sizeof cp);
  static int xhs[512]; int nx=0;
  for(int b=0;b<nb;b++){ int pk=0; for(int y=bt[b];y<bb[b];y++) if(rp[y]>pk) pk=rp[y];
    int a=-1,z=-1; for(int y=bt[b];y<bb[b];y++) if(rp[y]*2>=pk){ if(a<0)a=y; z=y; }
    xz0[b]=a; xz1[b]=z+1; xhs[nx]=z+1-a; nx++;
    for(int x=x0;x<x1;x++){ int h=0; for(int y=a;y<=z;y++) if(abs(g[y*W+x]-bg)>=thr){h=1;break;} cp[x]+=h; } }
  if(!nb){ printf("pitch=0 ink=0 ratio=0 line=0 xh=0 lp_xh=0 bands=0 runs=0 dim=0\n"); return 0; }
  // pitch: first autocorrelation peak >= 85% of the best in 6..48 px
  double mean=0; int N=x1-x0; for(int x=x0;x<x1;x++) mean+=cp[x]; mean/=N;
  double c0=0; for(int x=x0;x<x1;x++){ double d=cp[x]-mean; c0+=d*d; }
  static double R[64]; double best=0;
  for(int L=6;L<=48;L++){ double c=0; for(int x=x0;x+L<x1;x++) c+=(cp[x]-mean)*(cp[x+L]-mean); R[L]=c0>0?c/c0:0; if(R[L]>best) best=R[L]; }
  int pitch=0; for(int L=7;L<48;L++) if(R[L]>=0.85*best && R[L]>=R[L-1] && R[L]>=R[L+1]){ pitch=L; break; }
  // isolated ink runs in the x-height zone of each band
  static int runs[200000]; int nr=0;
  for(int b=0;b<nb;b++){ int run=0; for(int x=x0;x<=x1;x++){ int h=0; if(x<x1) for(int y=xz0[b];y<xz1[b];y++) if(abs(g[y*W+x]-bg)>=thr){h=1;break;}
      if(h) run++; else { if(run>0 && pitch && run<pitch && nr<200000) runs[nr++]=run; run=0; } } }
  qsort(runs,nr,sizeof(int),cmp); qsort(xhs,nx,sizeof(int),cmp);
  int dl[512],nd=0; for(int i=1;i<nb;i++){ int d=bt[i]-bt[i-1]; if(d>=14&&d<=80) dl[nd++]=d; } qsort(dl,nd,sizeof(int),cmp);
  double ink=nr?runs[nr/2]:0; int line=nd?dl[nd/2]:0, xh=nx?xhs[nx/2]:0;
  // dim: bands found at a low threshold (a dim line is under the font threshold), each band's peak deviation
  int t2=fgmax/5>12?fgmax/5:12; static int r2[4096]; for(int y=y0;y<y1;y++){ int c=0; for(int x=x0;x<x1;x++) if(abs(g[y*W+x]-bg)>=t2) c++; r2[y]=c; }
  static int bp[512]; int nq2=0;
  for(int y=y0;y<y1;){ if(!r2[y]){y++;continue;} int s=y,pk=0; while(y<y1&&r2[y]) y++; if(y-s>=6&&nq2<512){ for(int yy=s;yy<y;yy++) for(int x=x0;x<x1;x++){ int d=abs(g[yy*W+x]-bg); if(d>pk) pk=d; } bp[nq2++]=pk; } }
  qsort(bp,nq2,sizeof(int),cmp); int nq=nq2/5>0?nq2/5:1; int dimv=nq2?bp[nq/2]:0; double dim=nq2&&bp[nq2-1]?100.0*dimv/bp[nq2-1]:0;
  printf("pitch=%d ink=%.1f ratio=%.2f line=%d xh=%d lp_xh=%.2f bands=%d runs=%d dim=%.0f\n",pitch,ink,ink>0?pitch/ink:0,line,xh,xh?(double)line/xh:0,nb,nr,dim);
  return 0; }
