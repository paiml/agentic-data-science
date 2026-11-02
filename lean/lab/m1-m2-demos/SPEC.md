# Lean lab environment, M1-M2 demos (NOT PUBLISHED)

Code only: the import closure of the two mains (31 Lean sources) under `tree/lean/AgenticDS`, plus `lakefile.toml`, `lake-manifest.json`, `lean-toolchain` and the inputs the demos name: `datasets/penguins`, `datasets/golden/p1.json`, `datasets/fixtures/folds.csv`, `contracts/ads-lean-p1-v1.yaml`, `scripts/{Axioms.lean,contract-demos.txt,rerun-lean-demos.sh}`. No recordings, no internals.
- Source: paiml/agentic-data-science `lean/AgenticDS` at main `bf6c7b5276a83a55234ce0a07a370298042f131d`; `src/` is `git archive` of that commit, reduced to the closure; the lakefile drops m3/m4/ols-demo.
- Toolchain: `leanprover/lean4:v4.35.0`. Mathlib rev `e91b1280...` from the manifest.
- Nothing is uploaded to Coursera before the 18:00Z sync.
- elan 4.2.4, sha256 `42b94d42...1f63` (matches the GitHub release digest). Base image pinned by digest.

## Receipts
- `image-id.txt`: image built from a `git archive` export of this directory (build context, not the working tree).
- `proof-run-network-none.txt`: `docker run --rm --network none IMAGE proof.sh`, 20/20 demos 2/2, exit 0.
- `receipt-pv-lint.txt`: `pv lint contracts` PASS (0 errors, 0 warnings). `receipt-pv-sigma.txt`: `pv lint --gate sigma contracts` declines `NoCheckable`: this repo has no Σ ontology file, so there is nothing for the sigma gate or `pv ontology tbox` to read (exit 2 / "cannot read contracts/ontology.yaml").
