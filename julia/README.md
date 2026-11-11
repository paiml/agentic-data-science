# Agentic Data Science, Course B: Julia

This directory holds the code examples for **Agentic Data Science, Course B: Julia**, one of the five courses in the Agentic Data Science specialization by Pragmatic AI Labs. The course solves the same four data science problems (Palmer Penguins and UCI Wine Quality) in Julia, with an AI coding agent in the loop, under strict quality gates.

## Run

```bash
julia --project=julia/AgenticDS.jl -e "using Pkg; Pkg.instantiate()"   # first run only
julia --project=julia/AgenticDS.jl julia/AgenticDS.jl/examples/b-m1-p1/run.jl   # run from the repository root
```

## What lives here

- `AgenticDS.jl/`: the Julia package the course builds, with `src/`, `test/` and `examples/`.
- `AgenticDS.jl/examples/`: one runnable `run.jl` per example, each with its `example.ttl`.
- `gate/`: the pinned environment the quality gate runs in.

## Back to the project

See the [root README](../README.md) for the full course list, the datasets, the ontology and the quality gates.
