# E-M4-P4a: contracts as types (Lean 4)

Encodes data validity in a `ValidRow` subtype-like structure, proves that `clean` keeps exactly the rows that validate, never grows the list, and that the every-fifth-row split is a partition. Run by `make gate-lean` (`AgenticDSTest/P4.lean`).

```bash
make gate-lean
```
