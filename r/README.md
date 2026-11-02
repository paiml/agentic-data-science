# Agentic Data Science, Course C: R

This directory holds the code examples for **Agentic Data Science, Course C: R**, one of the five courses in the Agentic Data Science specialization by Pragmatic AI Labs. The course solves the same four data science problems (Palmer Penguins and UCI Wine Quality) in R, with an AI coding agent in the loop, under strict quality gates.

## Run

```bash
R CMD INSTALL r/agenticds   # once; install the packages named in r/agenticds/DESCRIPTION first
Rscript r/agenticds/inst/examples/c-m1-p1/run.R   # from the repository root
```

## What lives here

- `agenticds/`: the R package the course builds (loaders, NA policy, per-species profile, OLS, cross-validation, k-means, trees, benchmarks).
- `agenticds/inst/examples/`: one runnable `run.R` per example, each with its `example.ttl`.
- `agenticds/inst/examples/c-mN-vNN-*`: forty lesson examples (modules 1 to 4, ten each). Each is one short `run.R` that prints its checks and ends with a `contract:` line. From the repository root, run one in an R console with `source("r/agenticds/inst/examples/c-m1-v01-ticket/run.R")` after `library(agenticds)`.
- `agenticds/tests/`: the testthat suite behind the 100 percent coverage gate.

## Back to the project

See the [root README](../README.md) for the full course list, the datasets, the ontology and the quality gates.
