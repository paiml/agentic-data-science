# BM3: Course B (Julia), module 3 examples

Ten examples for module 3 (CART tree and fixed-start k-means on the Palmer penguins). One package, one example file per lesson.

- `src/vNN_name.jl`: the example file (no backslash, no tab).
- `src/BM3.jl`, `src/helpers.jl`, `src/tree.jl`: the plumbing (paths, fixtures, golden values, tree, table and verdict helpers).
- `data/`: verbatim copies of `datasets/penguins/penguins.csv`, `datasets/fixtures/split.csv`, `datasets/fixtures/centroids.csv` and `datasets/golden/p3.json` (the test compares them byte for byte with the repository copies).
- `contracts/ads-julia-examples-m3-v1.yaml` (repository root): the module contract.

Run an example after `using BM3`: `BM3.V04.main()` (and so on per example).

```bash
julia --project=julia/BM3 -e 'using BM3; BM3.V04.main()'   # from the repository root
```

`v07-gates` holds the native gates as data (`GATES`): a JuliaFormatter check on `julia/BM3` and `julia --project=julia/BM3 -e 'using Pkg; Pkg.test()'`. The package `Pkg.test` does not run them, so it cannot start itself.

## Gate

```bash
julia --project=julia/BM3 --inline=no -e 'using Pkg; Pkg.test()'   # JET, per-example testsets
scripts/julia-format.sh julia/BM3   # JuliaFormatter, whole package, no diff
scripts/gate-julia.sh               # loops over every julia/*/ package
```

`Pkg.test` runs one top-level testset (`BM3 suite`, so the final summary shows the suite totals) with JET `test_package` and one testset per example (golden values, a can-fail test, output without warnings).

## Not covered by pmat

pmat has no Julia analyzer, so `pmat quality-gate` does not look at these files and no pmat result is claimed for them. The Julia checks above are the gate.
