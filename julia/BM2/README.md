# BM2: Course B (Julia), Module 2 examples

One package, nine example files (`src/v01_ticket.jl`, `v02`, `v03`, `v05` ..
`v10`). The normal-equation example is `julia/PenguinsOLS`.

Run an example with `using BM2`, then `BM2.Vnn.main()`. Plumbing is in
`src/helpers.jl`. The module contract is
`contracts/ads-julia-examples-m2-v1.yaml`, the project contract is
`contracts/ads-julia-p2-v1.yaml`.

```bash
julia --project=julia/BM2 -e 'using BM2; BM2.V01.main()'   # from the repository root
```

The least-squares operator lives in `backslash` in `helpers.jl`, so the
example files contain no backslash.

## Gate

- `Pkg.test` (JET `test_package`, golden values, can-fail tests). No line-coverage gate for this package.
- JuliaFormatter, margin 56, no diff.
- `scripts/gate-julia.sh` loops over this package.
- v07 holds the two gate commands as data (the `GATES` list): a JuliaFormatter check on `julia/BM2` and the full `Pkg.test()`. The package `Pkg.test` does not run them, so it cannot start itself.
- `pv validate` and `pv lint` on `contracts/ads-julia-examples-m2-v1.yaml` and `contracts/ads-julia-p2-v1.yaml`.

pmat has no Julia analyzer, so there is no pmat result for this package.
This is not a pass; the Julia gates above are the checks that apply.
