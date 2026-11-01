# Lab: Summarise penguins by species (Module 1)

Graded programming assignment for **Agentic Data Science in Julia** (ads-c02-julia). Every function comes from the
`AgenticDS` package the course builds (`paiml/agentic-data-science`, `julia/AgenticDS.jl`).

## What you do
Open `starter/src/AgenticDS.jl`. `read_penguins` is given. Implement the three functions marked `TODO`:

1. `na_policy(df)`: drop a row with a missing value in any of `NUMERIC_COLS`; a missing `sex` alone keeps the row; the
   numeric columns come back as plain `Float64`.
2. `summarise_by_species(df)`: per species, sorted: `n`, then `<col>_mean` and `<col>_sd` for each measurement. The sd
   is the sample sd (n - 1).
3. `summary_json(s)`: `{"species":{"Adelie":{"n":3,"bill_length_mm":{"mean":..,"sd":..},...}}}`, species in the order of
   `s`, measurements in the order of `NUMERIC_COLS`.

## Run the tests
```bash
cd starter
julia --project=. -e 'using Pkg; Pkg.instantiate()'   # first run only
julia --project=. test/runtests.jl
```
The suite has 73 checks over a 9-row fixture (`data/penguins-mini.csv`). Every expected number can be done by hand.
You pass when the run exits 0.

## For the course team
- `solution/` is the reference answer and never ships to learners.
- `grade.sh` is the grader: it runs the learner tree against the grader's own `solution/test/runtests.jl` through the grader's `run.jl`, which writes the counts to a result file only it writes (learner stdout and exit code are never parsed). It is installed read-only at `/grader/` in the sandbox image, never in `/workspace`. `GRADER_DIR` has no fallback.
- `run-lab-proof.sh` records both runs (`run-starter.log`, `run-solution.log`); `falsify-grade.sh` is the grader's falsifier (10 arms, 5 mutants, real Julia; `julia-docker.sh` runs the pinned image with the network off).
- The fixture is a hand-made subset in the shape of Palmer Penguins; the full dataset checks (344 rows, golden
  `p1.json`) stay in the course's own demo repo, which has passed its gates.
