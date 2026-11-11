# Agentic Data Science, Course A: Rust

This directory is the home of the code examples for **Agentic Data Science, Course A: Rust**, one of the five courses in the Agentic Data Science specialization by Pragmatic AI Labs. The course solves the same four data science problems (Palmer Penguins and UCI Wine Quality) in Rust, with an AI coding agent in the loop, under strict quality gates. The stack is polars and aprender only.

## Run

The Rust examples land with the Rust course pull requests. Once they do, run them from this directory with:

```bash
cargo test                     # tests
cargo run                      # run the example
cargo fmt --check              # format check, width 68
cargo clippy -- -D warnings    # lint, zero warnings
```

## What lives here

Today, only `rustfmt.toml`, which sets the line width to 68 for the format check. When the examples land: a Cargo project built on polars and aprender, with its tests and its gate.

## Back to the project

See the [root README](../README.md) for the full course list, the datasets, the ontology and the quality gates.
