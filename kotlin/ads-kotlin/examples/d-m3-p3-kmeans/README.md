# D-M3-P3b: kmeans (Kotlin)

Lloyd k-means on z-scored features from the committed centroids; objective and cluster sizes match the golden within 1e-8.

```bash
cd kotlin && gradle :ads-kotlin:runClassify --args="../../datasets/penguins/penguins.csv ../../datasets/fixtures/split.csv ../../datasets/fixtures/centroids.csv"
make gate-kotlin
```
