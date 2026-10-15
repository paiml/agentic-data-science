# C-M1-P1: ingest and profile Palmer Penguins (R)

Reads the CSV with explicit column types, drops rows with a missing numeric measurement
(344 rows become 342), and prints per-species count, mean and sample SD for the four
measurement columns as JSON. The output matches `datasets/golden/p1.json` within 1e-9.

```bash
Rscript r/agenticds/inst/examples/c-m1-p1/run.R datasets/penguins/penguins.csv
make gate-r
```
