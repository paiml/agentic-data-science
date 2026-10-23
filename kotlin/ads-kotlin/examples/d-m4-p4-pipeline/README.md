# D-M4-P4a: Wine Quality pipeline (Kotlin)

Validates the red and white tables, holds out every fifth row, fits a linear quality model on the training rows and scores the held-out rows; RMSE and R squared match the golden within 1e-6.

```bash
cd kotlin && gradle :ads-kotlin:runWine --args="../../datasets/wine-quality/winequality-red.csv ../../datasets/wine-quality/winequality-white.csv"
make gate-kotlin
```
