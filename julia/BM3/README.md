# BM3: Course B (Julia), module 3 scene code

Ten recorded scenes for module 3 (CART tree and fixed-start k-means on the Palmer penguins). One package, one scene file per video.

- `src/vNN_name.jl`: the file shown on camera in vim. At most 25 lines, every line at most 56 columns, no backslash (the gate asserts all three by reading the file).
- `src/BM3.jl`, `src/helpers.jl`: the plumbing that is not shown (paths, fixtures, golden values, table and verdict helpers).
- `scenes/vNN-name.scene`: the manifest (shown file, ticks as line spans, REPL rows, the single typed command, the ready string, plot, estimated run time).
- `data/`: verbatim copies of `datasets/penguins/penguins.csv`, `datasets/fixtures/split.csv`, `datasets/fixtures/centroids.csv` and `datasets/golden/p3.json` (the test compares them byte for byte with the repository copies).
- `contracts/ads-julia-bm3-vNN-name-v1.yaml` (repository root): one falsifiable contract per scene.

Typed on camera, after `using BM3` has run off camera: `BM3.V04.main()` (and so on per scene).

`v07-gates` is a shell scene: its manifest has `shell = 1` and `run1..runN`, literal command lines typed at a shell prompt, each followed by a separate `echo "exit=$?"` that the recorder types. The commands are the native gates, nothing is wrapped or filtered: a native `julia --project=julia/gate -e` JuliaFormatter check on `julia/BM3` and `julia --project=julia/BM3 -e 'using Pkg; Pkg.test()'`. `src/v07_gates.jl` (the shown file) holds them as data (`GATES`) and a test requires `run1..N` to equal it. The package `Pkg.test` holds no v07 run, so it cannot start itself; `gate/v07.jl` runs the commands (after the suite, from `scripts/gate-julia.sh`), captures the whole output and asserts the last 16 rows hold `Test Summary`, `Testing BM3 tests passed` and `exit=0`. Its can-fail controls reject a missing summary, a missing pass line, a nonzero exit and a summary that scrolled out of the 16 rows.

## Gate

```bash
julia --project=julia/BM3 --inline=no -e 'using Pkg; Pkg.test()'   # JET, per-scene testsets, limits
scripts/julia-format.sh julia/BM3   # JuliaFormatter, whole package, no diff (off camera)
scripts/gate-julia.sh                                                              # loops julia/*/ scene projects, then runs gate/*.jl
```

`Pkg.test` runs one top-level testset (`BM3 suite`, so the final summary shows the suite totals) with JET `test_package`, one testset per scene (golden values, a can-fail test, line/column/backslash limits, tick spans parse as whole statements, output fits the REPL rows, last line equals the ready string).

## Not covered by pmat

pmat has no Julia analyzer, so `pmat quality-gate` does not look at these files and no pmat result is claimed for them. The Julia checks above are the gate.
