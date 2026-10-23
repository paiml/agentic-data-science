# E-M4-P4b: wine pipeline in exact rationals (Lean 4)

Fits quality on 11 features plus a colour dummy through exact normal equations on the training rows only, and matches the golden RMSE, R squared and per-colour means in `datasets/golden/p4.json`. Run by `make gate-lean` (`AgenticDSTest/P4.lean`).

```bash
make gate-lean
```
