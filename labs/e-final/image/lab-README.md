# Lab: prove the mean-shift law in Lean 4

You have a small Lean 4 file, `Mean.lean`, in this folder. It defines the sum of a list of integers and a
contract: adding `c` to every value adds `c` to the mean. One theorem, `sum_shift`, is left as `sorry`.
Your job is to replace that `sorry` with a proof the Lean kernel accepts.

## Steps

1. Open `Mean.lean` in the editor (it is in the project folder shown in the explorer).
2. Find `theorem sum_shift` and read the statement. The helper theorem `foldl_add_acc` above it is yours to use.
3. Replace `sorry` with a proof. Induction on `xs` is the natural route.
4. Open a terminal (Terminal, New Terminal) and run `lean Mean.lean`. A finished proof prints no warning and no error.
   While `sorry` is still there, Lean prints "declaration uses 'sorry'".
5. When `lean Mean.lean` is clean, submit the lab from the Coursera page.

## Rules

- Edit only `Mean.lean`. Keep the names `sumL`, `foldl_add_acc`, `sum_shift` and `checkContract` as they are.
- No `sorry`, `admit`, `native_decide`, new `axiom`s or new commands such as `#eval`. The grader refuses them.
- The lab uses core Lean only (no Mathlib). The toolchain is Lean 4.35.0.
