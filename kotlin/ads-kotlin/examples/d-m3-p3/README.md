# D-M3-P3: species tree and k-means (Kotlin)

A gini decision tree (rpart defaults) scored on the fixed test split, and Lloyd k-means on z-scored features from the fixed centroids. Both reproduce `datasets/golden/p3.json`.

```bash
cd kotlin && ./gradlew -q m3v01
make gate-kotlin
```
