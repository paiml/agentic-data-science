// text: text-size measure for the plot's title, legend and tick strips (ticks >= 22-24 px, title/legend 26-28 px).
// stdin = rgb24 crop of one rect (W*H); args: W H [fitR fitG fitB]. Background = the crop's modal colour; ink = Chebyshev distance >= 60 from it.
// Glyphs = runs of ink columns (columns with no ink separate them); only glyph-sized clusters count (height >= 8 px, width <= 40 px), so swatches
// and rules are ignored. size = 75th-percentile glyph height / 0.72 (cap/ascender height of a monospace or sans face is ~0.72 em; 50% coverage
// reads ~1 px low, so callers allow a 1 px tolerance in the threshold). fit_px = pixels within 48 of the fit colour (legend swatch).
// Prints: bbox=x0,y0,x1,y1 glyphs=<n> h75=<px> size=<px> ink_px=<n> fit_px=<n>   (bbox in crop coordinates, x1/y1 exclusive; 0s when no ink)
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static int cmpi(const void*a,const void*b){ return *(const int*)a-*(const int*)b; }
static int dist(const unsigned char*p,int r,int g,int b){ int a=abs(p[0]-r),c=abs(p[1]-g),d=abs(p[2]-b); return a>c?(a>d?a:d):(c>d?c:d); }
int main(int argc,char**argv){
  if(argc<3) return 2;
  int W=atoi(argv[1]),H=atoi(argv[2]); int fr=-1,fg=-1,fb=-1; if(argc>=6){ fr=atoi(argv[3]); fg=atoi(argv[4]); fb=atoi(argv[5]); }
  unsigned char*F=malloc((size_t)W*H*3); if(fread(F,1,(size_t)W*H*3,stdin)!=(size_t)W*H*3) return 2;
  static long h[1<<18]; for(long i=0;i<(long)W*H;i++){ unsigned char*p=F+i*3; h[((p[0]>>2)<<12)|((p[1]>>2)<<6)|(p[2]>>2)]++; }
  int k=0; for(int i=0;i<(1<<18);i++) if(h[i]>h[k]) k=i;
  long sr=0,sg=0,sb=0,n=0; for(long i=0;i<(long)W*H;i++){ unsigned char*p=F+i*3; if((((p[0]>>2)<<12)|((p[1]>>2)<<6)|(p[2]>>2))==k){ sr+=p[0];sg+=p[1];sb+=p[2];n++; } }
  int br=sr/n,bg=sg/n,bb=sb/n;
  int x0=W,y0=H,x1=0,y1=0; long ink=0,fitpx=0;
  static int colink[8192]; static int cmin[8192],cmax[8192];
  for(int x=0;x<W&&x<8192;x++){ cmin[x]=H; cmax[x]=-1; }
  for(int y=0;y<H;y++) for(int x=0;x<W;x++){ const unsigned char*p=F+((size_t)y*W+x)*3;
    if(dist(p,br,bg,bb)>=60){ ink++; if(x<x0)x0=x; if(x+1>x1)x1=x+1; if(y<y0)y0=y; if(y+1>y1)y1=y+1; if(x<8192){ colink[x]++; if(y<cmin[x])cmin[x]=y; if(y>cmax[x])cmax[x]=y; } }
    if(fr>=0 && dist(p,fr,fg,fb)<=48 && dist(p,br,bg,bb)>=60) fitpx++; }
  static int hs[8192]; int nh=0;
  for(int x=0;x<W&&x<8192;){ if(!colink[x]){ x++; continue; } int s=x,mn=H,mx=-1; while(x<W&&x<8192&&colink[x]){ if(cmin[x]<mn)mn=cmin[x]; if(cmax[x]>mx)mx=cmax[x]; x++; }
    int w=x-s,ht=mx-mn+1; if(ht>=8&&w<=40) hs[nh++]=ht; }
  qsort(hs,nh,sizeof(int),cmpi);
  int h75=nh?hs[(nh*3)/4>=nh?nh-1:(nh*3)/4]:0;
  if(!ink){ x0=y0=x1=y1=0; }
  printf("bbox=%d,%d,%d,%d glyphs=%d h75=%d size=%.1f ink_px=%ld fit_px=%ld\n",x0,y0,x1,y1,nh,h75,h75/0.72,ink,fitpx);
  return 0; }
