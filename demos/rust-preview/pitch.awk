BEGIN{FS="[(,)]"} NR>1{a[NR-1]=$3+0} END{N=NR-1; for(i=1;i<=N;i++)s+=a[i]; mu=s/N; for(i=1;i<=N;i++)a[i]-=mu
 best=0;bl=0; for(l=20;l<=45;l++){c=0;for(i=1;i+l<=N;i++)c+=a[i]*a[i+l]; if(c>best){best=c;bl=l}} print bl}
