# Lean playground file and lab: verification record

Measured on 2026-11-02 with Lean v4.35.0 (core only, no Mathlib).

## Playground file
- `playground/lean/e-m1-p1-mean.lean`, sha256 `e7a90bedcf22afdc8c6607c010663f3f8ea5672c5cb36d12613dda3bc4f02291`. The share URL is 2464 characters (code in the hash argument).
- `lean +v4.35.0 -DwarningAsError=true` compiles it and prints `contract: mean_shift OK`.
- A variant that breaks the runtime contract exits 1. A variant with a broken proof exits 1 with an elaboration error.

## Lab `labs/e-final`
- `tests/run.sh` on the starter (it contains `sorry`): exit 1. The parser pass accepts it, the kernel check refuses it (`sorry` is an axiom outside the allowed three).
- `tests/run.sh` on the solution: exit 0; the 3 deciding checks (parser, compile plus kernel check, axiom set) pass. Seven keyword-grep lines also run, but they are advisory notes only and never decide a grade.
- How the grade is decided:
  - A Lean-parser pass accepts only `def`, `theorem`, `example`, `namespace`, `section`, `end`, `open` and `variable` commands. It refuses imports, `deriving`, and any `unsafe`, `native` or elaborator-hook token. This runs on the exact bytes that are later compiled.
  - The learner file is compiled inside `bwrap` (read-only `/usr` and toolchain, no network, private `/tmp`, only its build directory writable). If `bwrap` is missing, the grade fails.
  - The compile and the parse are limited by `timeout` (`GRADER_TIMEOUT`, default 120 s) and `lean -M` (`GRADER_MEM_MB`, default 4096 MB).
  - A separate Lean program then replays the learner's declarations through the kernel, checks that `sumL` and the `sum_shift` statement are definitionally equal to a reference compiled by the grader, and checks that the theorem depends only on `propext`, `Classical.choice` and `Quot.sound`.
- `tests/falsify-toolchain.sh`: passes with 32 cheat fixtures refused by the full grader, 13 parser-only refusals, 10 refusals with the parser test removed plus 2 containment arms (the compile-time commands run inside the sandbox and the grade still passes), 4 honest solutions that must pass (words such as alternative, sorry, native and admit in comments, an identifier named init, a type continued at column 0, banned words inside a docstring and a string literal) and unit arms for the axiom check, which accepts the empty set (instance redefinition, a proof of `True`, indented and nested-comment tricks, an unbounded `decide`, a custom axiom, memory limit hits).

## Not measured
- The live Lean web editor with this file, and whether it accepts the file at this Lean version.
- The Coursera lab runtime.
- Mathlib theorems (`Stats.lean`) are not flattened into the playground file: there is no local Mathlib build.
