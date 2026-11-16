# E-M1-P1b: exact profile of Palmer Penguins (Lean 4)

Parses `penguins.csv` to exact rationals, applies the NA policy (344 rows become 342) and checks per-species n, mean and sample SD against `datasets/golden/p1.json` within 1e-9. Run by `make gate-lean` (`AgenticDSTest/Main.lean`).

```bash
make gate-lean
```
