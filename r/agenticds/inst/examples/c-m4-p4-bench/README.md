# C-M4-P4b: dplyr vs data.table (R)

Checks that both engines return the same per-colour aggregate, then times them. Timings vary by machine and are never part of a parity check.

```bash
ADS_ROOT=. Rscript r/agenticds/inst/examples/c-m4-p4-bench/run.R
make gate-r
```
