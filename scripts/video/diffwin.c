// diffwin: stability of a window. stdin = N gray8 frames of FS bytes each (the same rect sampled at several times); arg: FS.
// Prints: frames=<n> max_mad=<mean abs difference of any frame against frame 0, gray levels>. Used for beat windows (the text must stay) and
// for the plot reveal (the code pane must not shift: 0 px).
#include <stdio.h>
#include <stdlib.h>
int main(int argc,char**argv){
  if(argc<2) return 2;
  size_t fs=(size_t)atol(argv[1]); if(!fs) return 2;
  unsigned char*a=malloc(fs),*b=malloc(fs); if(fread(a,1,fs,stdin)!=fs){ printf("frames=0 max_mad=999\n"); return 0; }
  int n=1; double mx=0;
  while(fread(b,1,fs,stdin)==fs){ n++; double s=0; for(size_t i=0;i<fs;i++) s+= a[i]>b[i]?a[i]-b[i]:b[i]-a[i]; s/=fs; if(s>mx) mx=s; }
  printf("frames=%d max_mad=%.2f\n",n,mx); return 0; }
