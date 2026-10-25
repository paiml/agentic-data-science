# Agentic Data Science, Course E: Lean 4

This directory holds the code examples for **Agentic Data Science, Course E: Lean 4**, one of the five courses in the Agentic Data Science specialization by Pragmatic AI Labs. The course solves the same four data science problems (Palmer Penguins and UCI Wine Quality) in Lean 4, with an AI coding agent in the loop, under strict quality gates.

## Run

```bash
cd lean/AgenticDS
lake exe cache get   # download the Mathlib oleans
lake build
```

The `ols-demo` executable (`lake exe ols-demo`) lands with the Lean course examples.

## What lives here

- `AgenticDS/`: the Lake package the course builds (`AgenticDS/AgenticDS/{Csv,Profile,Stats}.lean`), pinned by `lean-toolchain` and `lake-manifest.json`.
- `AgenticDS/examples/`: one directory per example, each with its README and `example.ttl`.
- `AgenticDS/scripts/Axioms.lean`: the check that no proof leans on `sorry`.

## Back to the project

See the [root README](../README.md) for the full course list, the datasets, the ontology and the quality gates.
