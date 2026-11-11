# Agentic Data Science, Course D: Kotlin

This directory is the home of the code examples for **Agentic Data Science, Course D: Kotlin**, one of the five courses in the Agentic Data Science specialization by Pragmatic AI Labs. The course solves the same four data science problems in Kotlin, with an AI coding agent in the loop, under strict quality gates.

## Run

Run the examples from this directory with:

```bash
./gradlew -q run
```

Module examples (run from `kotlin/`): `./gradlew -q m1v01` (ingest), `m1v02` (profile), `m2v01` (OLS check against the golden), `m3v01` (species tree and k-means), `m4v01` (wine pipeline), `m4v02` (two engines, agreement before timing).

## What lives here

A Gradle project with a typed loader, the NA policy, the per-species profile, the OLS fit, a species tree with k-means, the wine pipeline and their gate.

## Back to the project

See the [root README](../README.md) for the full course list, the datasets, the ontology and the quality gates.

## Example

`cd kotlin && ./gradlew -q run` runs the penguins-ols example
(`PenguinsOls.kt`, 24 lines; helpers in `Example.kt`/`Report.kt`):
load, drop NA, fit by two solvers, plot by species, verdict.
It reads `datasets/penguins/penguins.csv` and writes `plot.png`
at the repo root.
