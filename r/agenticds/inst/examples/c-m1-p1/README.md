# C-M1-P1a: typed ingest and NA policy (R)

Reads the CSV with explicit column types and drops rows with a missing numeric measurement
(344 rows become 342; a missing `sex` alone keeps the row).

```bash
Rscript r/agenticds/inst/examples/c-m1-p1/run.R datasets/penguins/penguins.csv
make gate-r
```
