# C-M3-P3b: k-means from fixed centroids (R)

Runs Lloyd k-means (k = 3) on z-scored measurements from the committed starting centroids and prints the objective and cluster sizes; matches the golden within 1e-6.

```bash
ADS_ROOT=. Rscript r/agenticds/inst/examples/c-m3-p3-kmeans/run.R
make gate-r
```
