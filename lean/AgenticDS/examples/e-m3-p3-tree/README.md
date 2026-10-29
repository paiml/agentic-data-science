# E-M3-P3a: exact CART classifier on Penguins (Lean 4)

Grows a gini CART in exact rationals with rpart's minsplit 20, minbucket 7 and cost-complexity cut, rediscovers the flipper 207.5 and bill-length 43.35 splits, and matches the golden confusion matrix and accuracy in `datasets/golden/p3.json`. Run by `make gate-lean` (`AgenticDSTest/P3.lean`).

```bash
make gate-lean
```
