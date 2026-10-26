# C-M3-P3a: species decision tree (R)

Fits a deterministic rpart tree on the training rows of the committed split and prints the confusion matrix and accuracy on the 85 test rows (97.6%); matches the golden exactly.

```bash
ADS_ROOT=. Rscript r/agenticds/inst/examples/c-m3-p3-tree/run.R
make gate-r
```
