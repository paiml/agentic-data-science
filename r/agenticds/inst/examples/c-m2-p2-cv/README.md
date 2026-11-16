# C-M2-P2b: species model and fixed-fold CV (R)

Fits the species model with parsnip linear_reg() and prints pooled 5-fold CV RMSE using the committed fold file; matches the golden within 1e-6.

```bash
ADS_ROOT=. Rscript r/agenticds/inst/examples/c-m2-p2-cv/run.R
make gate-r
```
