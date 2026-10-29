# E-M2-P2b: exact OLS and 5-fold CV on Penguins (Lean 4)

Fits body_mass_g ~ flipper_length_mm in exact rationals, compares slope, intercept, R², RMSE and the fixed-fold (`folds.csv`) CV RMSE with `datasets/golden/p2.json`, and checks that the residual sums are exactly zero. Run by `make gate-lean` (`AgenticDSTest/P2.lean`).

```bash
make gate-lean
```
