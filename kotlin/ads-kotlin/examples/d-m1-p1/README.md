# D-M1-P1a: typed ingest and NA policy (Kotlin)

Reads the CSV through a typed DataFrame schema (`PenguinRow`) and drops rows with a missing numeric measurement (344 rows become 342; a missing `sex` alone keeps the row).

```bash
cd kotlin && gradle :ads-kotlin:runIngest --args=../datasets/penguins/penguins.csv
make gate-kotlin
```
