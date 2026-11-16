# c05 (Lean) end-of-course lab

Prove three statistics contracts in `starter/Lab.lean` (each starts as `sorry`): `lab_exact_mean`, `lab_variance_nonneg`, `lab_variance_shift`. `solution/Lab.lean` is the reference.
Needs the `lean/AgenticDS` project built (Mathlib cache). Coursera lab runtime image: NOT MEASURED (W8, LAB-STD-001 L2).

## Run

Grade the starter. It fails on purpose and names each unproved task (exit 1):

```bash
# expect: 1
tests/lab-run.sh starter
```

Grade the reference solution. Every task passes (exit 0):

```bash
tests/lab-run.sh solution
```

You are done when `tests/lab-run.sh <your dir>` exits 0 (all tasks proved), 1 (named failures) or 2 (not measured).

## Checks (course staff)

Audit the pair (starter exit 1 with named failing tasks, solution exit 0):

```bash
tests/lab-verify.sh /dev/null
```

Every block above is run verbatim and in order by `tests/readme-run.sh`; a failing step turns the lab red (`tests/readme-falsify.sh`).
