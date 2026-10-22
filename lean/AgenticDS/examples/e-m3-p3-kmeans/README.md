# E-M3-P3b: weighted k-means and confusion total (Lean 4)

Runs Lloyd k-means with 1/variance weights (equal to z-scoring), matches the golden objective and cluster sizes, and relies on the kernel-checked `assign_step_optimal` and `confusion_total` theorems. Run by `make gate-lean` (`AgenticDSTest/P3.lean`).

```bash
make gate-lean
```
