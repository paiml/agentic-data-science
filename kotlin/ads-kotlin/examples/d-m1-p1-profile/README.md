# D-M1-P1b: per-species profile (Kotlin)

Prints per-species count, mean and sample SD (n-1) of the four measurement columns as JSON. The output matches `datasets/golden/p1.json` within 1e-9.

```bash
cd kotlin && gradle :ads-kotlin:runProfile --args=../../datasets/penguins/penguins.csv
make gate-kotlin
```
