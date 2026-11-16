# C-M4-P4a: Wine Quality pipeline and report (R)

Validates, splits (every fifth row is test), fits a linear quality model and prints held-out RMSE and R squared, then writes the report artifact; matches the golden within 1e-6.

```bash
ADS_ROOT=. Rscript r/agenticds/inst/examples/c-m4-p4-pipeline/run.R
make gate-r
```
