// edge: plot-pane edge per frame (round 4 = r3 + xl thin-divider term). stdin = rgb24 1920x1080 frames. out per frame: edge xb xi bgshare chrome maxchain xl divx
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define W 1920
#define H 1080
static unsigned char F[H*W*3], D[H*W];

int main(void){
  static int flatc[W], fcol[W], forn[W], chrome[H];
  while(fread(F,1,sizeof F,stdin)==sizeof F){
    // 1-3 per-row background = majority colour of x 0..599 of that row (6-bit quantised vote, then mean of the matching pixels); no dominant colour (< 35%) = chrome row, skipped; > 10% chrome rows = not measured = HIT
    int nch=0, nrows=0; double share=1.0;
    for(int y=0;y<H;y++){ unsigned char*row=F+y*W*3; int cand=-1, v=0;
      for(int x=0;x<600;x++){ unsigned char*p=row+x*3; int k=((p[0]>>2)<<12)|((p[1]>>2)<<6)|(p[2]>>2); if(v==0){cand=k;v=1;} else if(k==cand) v++; else v--; }
      long sr=0,sg=0,sb=0,n=0; for(int x=0;x<600;x++){ unsigned char*p=row+x*3; int k=((p[0]>>2)<<12)|((p[1]>>2)<<6)|(p[2]>>2); if(k==cand){sr+=p[0];sg+=p[1];sb+=p[2];n++;} }
      chrome[y]=(n<210); if(chrome[y]){ nch++; memset(D+y*W,0,W); continue; }
      if((double)n/600<share) share=(double)n/600;
      int br=sr/n,bgc=sg/n,bb=sb/n;
      for(int x=0;x<W;x++){ unsigned char*p=row+x*3; int a=abs(p[0]-br),b=abs(p[1]-bgc),c=abs(p[2]-bb); D[y*W+x]=a>b?(a>c?a:c):(b>c?b:c); } }
    if(nch>H/10){ printf("0 0 0 %.2f %d 0 0 0\n",share,nch); fflush(stdout); continue; }
    nrows=H-nch;
    // 4 background shift: locally smooth pixel (|p-p(x+-2)|<=12 per channel) that differs from bg by >3; >=20% of rows for 16 consecutive columns
    memset(flatc,0,sizeof flatc);
    for(int y=0;y<H;y++){ if(chrome[y]) continue;
      for(int x=602;x<W-2;x++){ if(D[y*W+x]<=3) continue; unsigned char*p=F+(y*W+x)*3,*l=p-6,*r=p+6; int ok=1;
        for(int c=0;c<3;c++) if(abs(p[c]-l[c])>12||abs(p[c]-r[c])>12){ok=0;break;}
        if(ok) flatc[x]++; } }
    for(int x=0;x<W;x++) fcol[x]=(x>=600 && flatc[x]*5>=nrows);
    int xb=0, run=0;
    for(int x=600;x<W;x++){ if(fcol[x]){ run++; if(run>=16){ xb=x-15; break; } } else run=0; }
    int lim=xb?xb:W;
    // 5/6 per-row code chain: ink cells (8 px, D>24) pooled over rows y-12..y+12; chain starts at the leftmost ink cell and walks right across gaps < 96 px; ink right of the chain end is foreign
    static int cs[H+1][W/8]; memset(cs[0],0,sizeof cs[0]);
    for(int y=0;y<H;y++){ static unsigned char cr[W/8]; memset(cr,0,sizeof cr); if(!chrome[y]) for(int x=0;x<lim;x++) if(D[y*W+x]>24) cr[x>>3]=1; for(int c=0;c<W/8;c++) cs[y+1][c]=cs[y][c]+cr[c]; }
    static int er[H]; int maxchain=0; memset(forn,0,sizeof forn);
    for(int y=0;y<H;y++){ er[y]=-1; if(chrome[y]) continue; int y0=y-12<0?0:y-12, y1=y+13>H?H:y+13; int first=-1, last=-1, cl=0;
      for(int c=0;c<lim/8;c++){ if(cs[y1][c]-cs[y0][c]>0){ if(first<0){ first=c; last=c; cl=1; } else if(c-last<=12 || (cl<=8 && c-last<=20)){ cl=(c-last<=12)?cl+(c-last):cl+9; last=c; } else break; } }
      if(first>=0 && first*8<600) er[y]=last*8+7; }
    for(int y=0;y<H;y++){ if(chrome[y]) continue; int e=-1; for(int d=-8;d<=8;d++){ int yy=y+d; if(yy>=0&&yy<H&&er[yy]>e) e=er[yy]; } if(e>maxchain) maxchain=e;
      for(int x=600;x<lim;x++) if(D[y*W+x]>24 && x>e) forn[x]++; }
    // xi must belong to a pane-sized structure: foreign ink at or right of x spans >= 15% of the non-chrome rows (a small corner watermark is not a plot)
    static int rmx[W+1]; memset(rmx,0,sizeof rmx);
    for(int y=0;y<H;y++){ if(chrome[y]) continue; int e=-1; for(int d=-8;d<=8;d++){ int yy=y+d; if(yy>=0&&yy<H&&er[yy]>e) e=er[yy]; } int m=-1; for(int x=W-1;x>=600&&x>e;x--) if(D[y*W+x]>24){m=x;break;} if(m>=0) rmx[m]++; }
    for(int x=W-1;x>=0;x--) rmx[x]+=rmx[x+1];
    int xi=0; for(int x=600;x<lim;x++) if(forn[x]>=2 && rmx[x]*100>=15*nrows){xi=x;break;}
    // xl (round 4, fixes o5): a thin full-height divider. First x>=600 where >=60% of the non-chrome rows hold a pixel whose luma differs by >=8 from BOTH x-3 and x+3 with the same sign
    // (a 1-2 px line stands out against both sides; a plain step or a glyph stroke does not span the rows). A full-height editor colour column in the code area would read here: it fails safe (smaller x).
    static int lcnt[W]; memset(lcnt,0,sizeof lcnt);
    for(int y=0;y<H;y++){ if(chrome[y]) continue; unsigned char*r=F+y*W*3;
      for(int x=103;x<W-3;x++){ int a=r[x*3]+r[x*3+1]+r[x*3+2], l=r[(x-3)*3]+r[(x-3)*3+1]+r[(x-3)*3+2], q=r[(x+3)*3]+r[(x+3)*3+1]+r[(x+3)*3+2];
        int dl=(a-l)/3, dr=(a-q)/3; if(abs(dl)>=8 && abs(dr)>=8 && ((dl>0)==(dr>0))) lcnt[x]++; } }
    int xl=0; for(int x=600;x<W-3;x++) if(lcnt[x]*100>=60*nrows){ xl=x; break; }
    // divx (round 4): a full-height 1-3 px divider anywhere from x=100 (T2pre / box). Replaces the old column-mean + vertical-gradient scan, which false-hits aligned glyph gaps at 14 px cells.
    int divx=0; for(int x=100;x<1850;x++) if(lcnt[x]*100>=85*nrows){ divx=x; break; }
    int edge=0; { int c[3]={xb,xi,xl}; for(int i=0;i<3;i++) if(c[i] && (!edge || c[i]<edge)) edge=c[i]; }
    printf("%d %d %d %.2f %d %d %d %d\n",edge,xb,xi,share,nch,maxchain,xl,divx); fflush(stdout);
  }
  return 0; }
