// plot: plot-legibility measure. stdin = rgb24 crop of the plot rect (W*H); args: W H fitR fitG fitB.
// modal_run: most common horizontal run length (px, runs >= 2 px; 1 px runs are antialiasing and hairlines) of non-background pixels (a half-block mosaic reads 12+; native markers 5-6).
// fit_thick: perpendicular thickness (px) of the fit-colour line (median vertical run / sqrt(1+slope^2)); fit_cols_pct: % of columns that hold fit colour.
// fit_contrast: WCAG contrast ratio of the fit colour against the plot background.
// fit_cont_pct: % of the fit-colour columns whose centre lies within 4 px of the straight chord between the first and last fit column (a line is continuous, scattered markers of the same colour are not).
// grid: modal colour of the long (>= half the width) horizontal ink runs, i.e. the spine/grid colour ("none" when the crop has no such run: feed the whole plot rect for this).
// Prints: bg=rrggbb modal_run=<px> fit_cols_pct=<n> fit_thick=<px> fit_contrast=<ratio> fit_cont_pct=<n> grid=rrggbb|none
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
static int dist(const unsigned char*p,int r,int g,int b){ int a=abs(p[0]-r),c=abs(p[1]-g),d=abs(p[2]-b); return a>c?(a>d?a:d):(c>d?c:d); }
static double lin(int v){ double s=v/255.0; return s<=0.03928?s/12.92:pow((s+0.055)/1.055,2.4); }
static double lum(int r,int g,int b){ return 0.2126*lin(r)+0.7152*lin(g)+0.0722*lin(b); }
static int cmpd(const void*a,const void*b){ double x=*(const double*)a,y=*(const double*)b; return x<y?-1:x>y; }
int main(int argc,char**argv){
  if(argc<6) return 2;
  int W=atoi(argv[1]),H=atoi(argv[2]),fr=atoi(argv[3]),fg=atoi(argv[4]),fb=atoi(argv[5]);
  unsigned char*F=malloc((size_t)W*H*3); if(fread(F,1,(size_t)W*H*3,stdin)!=(size_t)W*H*3) return 2;
  static long h[1<<18]; for(long i=0;i<(long)W*H;i++){ unsigned char*p=F+i*3; h[((p[0]>>2)<<12)|((p[1]>>2)<<6)|(p[2]>>2)]++; }
  int k=0; for(int i=0;i<(1<<18);i++) if(h[i]>h[k]) k=i;
  long sr=0,sg=0,sb=0,n=0; for(long i=0;i<(long)W*H;i++){ unsigned char*p=F+i*3; if((((p[0]>>2)<<12)|((p[1]>>2)<<6)|(p[2]>>2))==k){ sr+=p[0];sg+=p[1];sb+=p[2];n++; } }
  int br=sr/n,bg=sg/n,bb=sb/n;
  static long rl[65]; for(int y=0;y<H;y++){ int run=0; for(int x=0;x<=W;x++){ int ink=(x<W)&&dist(F+((size_t)y*W+x)*3,br,bg,bb)>40;
      if(ink) run++; else { if(run>0) rl[run>64?64:run]++; run=0; } } }
  int mode=2; for(int i=2;i<=64;i++) if(rl[i]>rl[mode]) mode=i;
  static int cy[8192]; int ncol=0; double first=-1,last=-1,fx=0,lx=0; static double runs[8192]; int nr=0;
  for(int x=0;x<W&&x<8192;x++){ int best=0,bs=0,cur=0,cs=0; for(int y=0;y<H;y++){ if(dist(F+((size_t)y*W+x)*3,fr,fg,fb)<=48 && dist(F+((size_t)y*W+x)*3,br,bg,bb)>40){ if(!cur) cs=y; cur++; if(cur>best){best=cur;bs=cs;} } else cur=0; }
    cy[x]=bs+best/2; if(best){ ncol++; runs[nr++]=best; if(first<0){first=cy[x];fx=x;} last=cy[x]; lx=x; } }
  double thick=0; if(nr){ qsort(runs,nr,sizeof(double),cmpd); double med=runs[nr/2]; double slope=(lx>fx)?(last-first)/(lx-fx):0; thick=med/sqrt(1+slope*slope); }
  int cont=0; { double slope=(lx>fx)?(last-first)/(lx-fx):0;
    for(int x=0;x<W&&x<8192;x++){ int best=0,bs=0,cur=0,cs=0; for(int y=0;y<H;y++){ if(dist(F+((size_t)y*W+x)*3,fr,fg,fb)<=48 && dist(F+((size_t)y*W+x)*3,br,bg,bb)>40){ if(!cur) cs=y; cur++; if(cur>best){best=cur;bs=cs;} } else cur=0; }
      if(best){ double ex=first+slope*(x-fx); double d=(bs+best/2)-ex; if(d<0)d=-d; if(d<=4) cont++; } } }
  static long gh[1<<18]; { int mw=W/2; for(int y=0;y<H;y++){ int run=0,ri=0; for(int x=0;x<=W;x++){ int ink=(x<W)&&dist(F+((size_t)y*W+x)*3,br,bg,bb)>40;
        if(ink){ run++; ri=x; } else { if(run>=mw){ const unsigned char*p=F+((size_t)y*W+ri)*3; gh[((p[0]>>2)<<12)|((p[1]>>2)<<6)|(p[2]>>2)]+=run; } run=0; } } } }
  int gk=0; for(int i=0;i<(1<<18);i++) if(gh[i]>gh[gk]) gk=i;
  char gs[16]; if(gh[gk]>0) snprintf(gs,sizeof gs,"%02x%02x%02x",((gk>>12)&63)<<2|2,((gk>>6)&63)<<2|2,(gk&63)<<2|2); else snprintf(gs,sizeof gs,"none");
  double l1=lum(fr,fg,fb),l2=lum(br,bg,bb); double hi=l1>l2?l1:l2, lo=l1>l2?l2:l1;
  printf("bg=%02x%02x%02x modal_run=%d fit_cols_pct=%.0f fit_thick=%.1f fit_contrast=%.1f fit_cont_pct=%.0f grid=%s\n",br,bg,bb,mode,100.0*ncol/W,thick,(hi+0.05)/(lo+0.05),ncol?100.0*cont/ncol:0.0,gs);
  return 0; }
