# C-M1-P1b: per-species profile (R)

Prints per-species count, mean and sample SD (n-1) of the four measurement columns as JSON.
The output matches `datasets/golden/p1.json` within 1e-9.

```bash
Rscript r/agenticds/inst/examples/c-m1-p1-profile/run.R datasets/penguins/penguins.csv
make gate-r
```
