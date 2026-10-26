# BM1: Course B (Julia), Module 1 examples

Ten examples, one file each:

| Example | File |
|---|---|
| v01 | `src/v01_ticket.jl` |
| v02 | `src/v02_ingest.jl` |
| v03 | `src/v03_generate.jl` |
| v04 | `src/v04_profile.jl` |
| v05 | `src/v05_green.jl` |
| v06 | `src/v06_json.jl` |
| v07 | `src/v07_gates.jl` |
| v08 | `src/v08_mutants.jl` |
| v09 | `src/v09_parse.jl` |
| v10 | `src/v10_wrapup.jl` |

Run an example with `using BM1`, then `BM1.Vnn.main()`. The plumbing (paths,
golden values, verdict line, output capture) lives in `src/helpers.jl`.
The module contract is `contracts/ads-julia-examples-m1-v1.yaml`.

```bash
julia --project=julia/BM1 -e 'using BM1; BM1.V04.main()'   # from the repository root
```

## Gates

- `Pkg.test()` runs JET `test_package`, the run output checks and one testset
  per example, each with a test that can fail.
- Line coverage is measured with `Pkg.test(coverage = true)` and Coverage.jl
  from `julia/gate`.
- JuliaFormatter (margin 56, `.JuliaFormatter.toml`) shows no diff on the whole
  package (`scripts/julia-format.sh julia/BM1`).
- `scripts/gate-julia.sh` runs the package together with the other Julia packages.

## pmat

pmat has no Julia analyzer, so there is no pmat quality result for this
package and none is claimed. The checks above are the whole gate.

## Notes

v05 runs the real AgenticDS test suite in a subprocess (about 50 s). v08 runs
two representative mutants. v07 holds the three gate commands as data: `make
gate-shacl`, the JuliaFormatter check on `julia/BM1` and the full
`Pkg.test()`. The package's own `Pkg.test()` does not run them, so it cannot
start itself. v09 uses `tryparse` so that no CSV warning is printed.
