# BM4: Course B (Julia), Module 4 scenes

Ten scene files (`src/v01_ticket.jl` .. `src/v10_wrapup.jl`) for the
Wine Quality pipeline (problem P4). Each is the file shown on camera,
with one manifest in `scenes/` and one contract in `contracts/`
(`ads-julia-bm4-vNN-name-v1.yaml`). Plumbing is in `src/helpers.jl`
and `src/BM4.jl`.

Run a scene: `julia --project=julia/BM4 -e 'using BM4; BM4.V04.main()'`

Gate: `Pkg.test()` (JET, golden values, can-fail tests, layout limits,
tick spans), 100% line coverage of `src/`, JuliaFormatter margin 56.

## pmat

pmat has no Julia analyzer. No pmat result is claimed for this package;
quality here rests on the Julia gate above, not on a pmat pass.

## Reshaped scenes

v01 cuts the contract header to 57 columns; v05 runs the leaky mutant
in-process with golden checks instead of the 2-minute suite; v07 checks
dataset checksums and licenses plus an in-Julia shape check instead of
Jena SHACL and the 7-minute gate. See `note =` in each manifest.
