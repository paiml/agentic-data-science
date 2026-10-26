# BM2 - Course B (Julia), Module 2 scene code

One package, nine on-camera scene files (`src/v01_ticket.jl`, `v02`,
`v03`, `v05` .. `v10`) plus manifests in `scenes/`. Scene v04 (the normal
equation) is `julia/PenguinsOLS`; its manifest is
`julia/PenguinsOLS/scenes/v04-normal-eq.scene`.

On camera: `using BM2`, then `BM2.Vnn.main()`. Plumbing is in
`src/helpers.jl`, not in the shown files.

Limits asserted by `test/runtests.jl`: shown file at most
25 lines, 56 columns, no backslash (the least-squares operator
lives in `backslash` in `helpers.jl`), well-formed whole-statement ticks.

## Gate

- `Pkg.test` (JET `test_package`, golden values, can-fail tests). No line-coverage gate for this package.
- JuliaFormatter, margin 56, no diff.
- `scripts/gate-julia.sh` loops over this package.
- Scene v07 is a shell scene (`shell = 1` in `scenes/v07-gate.scene`): the keys `run1`, `run2` are the literal command lines typed at a shell prompt from the repo root, each followed by a separate `echo "exit=$?"` typed by the recorder. The commands are a native `julia --project=julia/gate -e` JuliaFormatter check on `julia/BM2` and the native `julia --project=julia/BM2 -e 'using Pkg; Pkg.test()'`. Nothing from Julia prints `exit=` or a verdict; the ready line is the tool's own `Testing BM2 tests passed`. `src/v07_gate.jl` is the shown file (data: the GATES list); the package Pkg.test holds no v07 test. `gate/v07.jl`, run by `scripts/gate-julia.sh` after the package Pkg.test, runs the manifest commands through a shell, asserts the last 16 rows hold `Test Summary`, the pass line and `exit=0`, and has can-fail controls (bad format, nonzero exit, truncated frames).
- `pv validate` and `pv lint` on `contracts/ads-julia-bm2-*.yaml`.

pmat has no Julia analyzer, so there is no pmat result for this package.
This is not a pass; the Julia gates above are the checks that apply.
