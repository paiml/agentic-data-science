# E-M1-P1a: verified mean and variance (Lean 4)

Defines `mean` and `variance` over any field and proves `mean_const`, `variance_nonneg` and `variance_shift` (shift invariance). Axioms are limited to propext, Classical.choice and Quot.sound; `scripts/Axioms.lean` prints them and `make gate-lean` refuses anything else.

```bash
make gate-lean
```
