# BM1: Course B (Julia), Module 1 scene code

Ten scenes, one file each, shown on camera in vim:

| Scene | File | Manifest |
|---|---|---|
| v01 | `src/v01_ticket.jl` | `scenes/v01-ticket.scene` |
| v02 | `src/v02_ingest.jl` | `scenes/v02-ingest.scene` |
| v03 | `src/v03_generate.jl` | `scenes/v03-generate.scene` |
| v04 | `src/v04_profile.jl` | `scenes/v04-profile.scene` |
| v05 | `src/v05_green.jl` | `scenes/v05-green.scene` |
| v06 | `src/v06_json.jl` | `scenes/v06-json.scene` |
| v07 | `src/v07_gates.jl` | `scenes/v07-gates.scene` |
| v08 | `src/v08_mutants.jl` | `scenes/v08-mutants.scene` |
| v09 | `src/v09_parse.jl` | `scenes/v09-parse.scene` |
| v10 | `src/v10_wrapup.jl` | `scenes/v10-wrapup.scene` |

Each scene runs as `BM1.Vnn.main()` after `using BM1`. The plumbing (paths,
golden, verdict line, output capture) lives in `src/helpers.jl` and is not
shown on camera. Contracts: `contracts/ads-julia-bm1-vNN-*-v1.yaml`.

## Gates

- `Pkg.test()` runs JET `test_package`, the scene layout checks (at most 25
  lines, 56 columns, no backslash, whole-statement ticks), the run output checks and
  one testset per scene, each with a test that can fail.
- Line coverage is measured with `Pkg.test(coverage = true)` and Coverage.jl
  from `julia/gate` (the CI gate).
- JuliaFormatter (margin 56, `.JuliaFormatter.toml`) shows no diff on the whole
  package (`scripts/julia-format.sh` off camera, the native `julia -e` check on camera).
- `gate/v07.jl` (run by `scripts/gate-julia.sh` after the package's own
  `Pkg.test()`) runs the v07 commands natively and checks the final frame.
- `scripts/gate-julia.sh` runs the package with the other scene projects.

## pmat

pmat has no Julia analyzer, so there is no pmat quality result for this
package and none is claimed. The checks above are the whole gate.

## Reshaped scenes

v05 runs the real AgenticDS test suite in a subprocess (about 50 s). v08 runs
two representative mutants, so it fits the 90 s limit. v07 is a shell scene (`shell = 1` in its manifest). The recorder types
`run1..runN` at a shell prompt in the repo root, and each line is followed by a
separate `echo "exit=$?"` typed by the recorder. The lines are the literal
commands: `make gate-shacl`, the native `julia --project=julia/gate -e` JuliaFormatter check on `julia/BM1` and the native
full `julia --project=julia/BM1 -e 'using Pkg; Pkg.test()'` (about 3 minutes,
`est_run_s = 300`). There is no Julia wrapper, no environment guard and no
filter. The package's own `Pkg.test()` holds no v07 run, so it cannot start
itself; `gate/v07.jl` runs the same commands in a shell after it, asserts that the
last 16 rows hold the Test Summary table, `Testing BM1 tests passed` and
`exit=0`, and has can-fail controls (a badly formatted file, a failing command).
`src/v07_gates.jl` is the displayed file: the command lines as data, checked
against the manifest. v09 uses `tryparse` so that no CSV warning is
printed. See the `note =` line in each manifest.
