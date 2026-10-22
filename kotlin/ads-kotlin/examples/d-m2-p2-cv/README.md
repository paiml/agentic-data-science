# D-M2-P2b: Fixed-fold cross-validation (Kotlin)

Pooled 5-fold out-of-fold CV RMSE over the committed fold file; matches the golden within 1e-8 and refuses leakage.

```bash
cd kotlin && gradle :ads-kotlin:runRegress --args="../../datasets/penguins/penguins.csv ../../datasets/fixtures/folds.csv"
make gate-kotlin
```
