# D-M3-P3a: tree (Kotlin)

Gini decision tree (rpart defaults) trained on the fixed split; accuracy and confusion match the golden within 1e-8.

```bash
cd kotlin && gradle :ads-kotlin:runClassify --args="../../datasets/penguins/penguins.csv ../../datasets/fixtures/split.csv ../../datasets/fixtures/centroids.csv"
make gate-kotlin
```
