# D-M2-P2a: OLS and species model (Kotlin)

Closed-form OLS (normal equations) of body mass on flipper length, plus the species model; metrics match the golden within 1e-8.

```bash
cd kotlin && gradle :ads-kotlin:runRegress --args="../../datasets/penguins/penguins.csv ../../datasets/fixtures/folds.csv"
make gate-kotlin
```
