[![CI](https://github.com/paiml/agentic-data-science/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/paiml/agentic-data-science/actions/workflows/ci.yml)

# Agentic Data Science: code examples

![Agentic Data Science](assets/hero.png)

Runnable, tested code examples for the **Agentic Data Science** specialization by Pragmatic AI Labs: the same four data science problems solved in five languages with an AI coding agent in the loop, under strict quality gates.

## The five courses

| Course | Language |
|---|---|
| C | R |
| B | Julia |
| D | Kotlin |
| A | Rust |
| E | Lean 4 |

Specialization: https://www.coursera.org/specialization/agentic-data-science (link goes live at launch).

## Layout

- `datasets/`: Palmer Penguins and UCI Wine Quality, each with LICENSE and SHA256SUMS; fixed folds, splits and centroids in `fixtures/`; golden reference numbers in `golden/`.
- `ontology/`: vocabulary and SHACL shapes that every example's `example.ttl` must satisfy.
- Language packages (`r/`, `julia/`, `kotlin/`, `rust/`, `lean/`) are added as each course's examples land.

## Set up your machine

Continuous integration runs these same steps on a stock GitHub-hosted machine (Ubuntu 24.04), and a weekly check repeats the learner steps on the latest Ubuntu and macOS. Run them from the repository root.

### Ubuntu and macOS (all courses)

Lean 4 (Course E): install elan once, then fetch the Mathlib oleans and build; `lean-toolchain` pins the Lean version.

```bash
curl -sSfL https://elan.lean-lang.org/elan-init.sh | sh -s -- -y --default-toolchain none
export PATH="$HOME/.elan/bin:$PATH"
cd lean/AgenticDS
lake exe cache get
lake build
```

Julia 1.12 (Course B): install Julia from https://julialang.org/downloads/, then:

```bash
julia --project=julia/AgenticDS.jl -e "using Pkg; Pkg.instantiate()"
julia --project=julia/AgenticDS.jl -e "using Pkg; Pkg.test()"
for e in julia/AgenticDS.jl/examples/*/run.jl; do julia --project=julia/AgenticDS.jl "$e" > /dev/null; done
```

R 4.5 (Course C): install R from https://cran.r-project.org, then the packages named in `r/agenticds/DESCRIPTION`, then:

```bash
R CMD INSTALL r/agenticds
ADS_ROOT="$PWD" Rscript -e 'testthat::test_dir("r/agenticds/tests/testthat", package = "agenticds", load_package = "installed")'
for e in r/agenticds/inst/examples/*/run.R; do Rscript "$e" > /dev/null; done
```

### Ubuntu only

The CI R job installs these system libraries first; do the same on your own Ubuntu machine:

```bash
sudo apt-get update && sudo apt-get install -y libblas3 liblapack3 gfortran
```

Quality tools (styler, lintr, covr, JuliaFormatter, Coverage.jl, Apache Jena) are not needed to run the examples; they run in separate pinned CI jobs (`make gate-r`, `gate-julia`, `gate-shacl`).

## Run the gates

```bash
make gate
```


## Format and lint gate

CI jobs for R, Julia and Lean run a format and lint check with zero diff and zero warnings. Line width is 68 in every config. The Kotlin and Rust rows are config only until their first code lands: Kotlin M1 (#23) brings its own gradle job with ktlint and detekt, Rust M1 (#47) its own rust job; each pins its tools in that PR.

| Language | Format | Lint | Pinned by |
|---|---|---|---|
| R | styler (tidyverse style) check | lintr, `line_length_linter(68)` | `scripts/r-pins.txt` (CRAN snapshot 2026-10-20) |
| Julia | JuliaFormatter check, `margin = 68` | JET.jl (in `Pkg.test`) | `julia/*/Manifest.toml` |
| Kotlin (config only) | ktlint check, `kotlin/.editorconfig` | detekt | set in the Kotlin M1 PR |
| Lean 4 | none | `warningAsError` + Mathlib style linters, `maxLineLength = 68` | `lean-toolchain`, `lake-manifest.json` |
| Rust (config only) | rustfmt `--check`, `rust/rustfmt.toml` | clippy `-D warnings` | set in the Rust M1 PR |

Lean has no official formatter, so the Lean gate is the linter set only. styler has no line-width setting; lintr enforces the 68 limit on R code. The Mathlib header linter is set to the MIT licence text this repo uses.

## Dataset licences

- Palmer Penguins: CC0 1.0 (Palmer Station LTER data policy).
- UCI Wine Quality: CC BY 4.0. Cortez, P. et al. (2009), doi:10.24432/C56S3T.

## Hero image

`scripts/hero.sh` draws `assets/hero.svg` from `datasets/penguins/penguins.csv` (one dot per row); `rmedia svg2png` renders `assets/hero.png`.
