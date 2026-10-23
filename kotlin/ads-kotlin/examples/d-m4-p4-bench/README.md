# D-M4-P4b: DataFrame vs collections (Kotlin)

Checks that both engines return the same per-colour aggregate, then times them. Timings vary by machine and are never part of a parity check.

```bash
cd kotlin && gradle :ads-kotlin:runBench --args="../../datasets/wine-quality/winequality-red.csv ../../datasets/wine-quality/winequality-white.csv"
make gate-kotlin
```
