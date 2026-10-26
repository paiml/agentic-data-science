# Agentic Data Science, Course D: Kotlin

This directory is the home of the code examples for **Agentic Data Science, Course D: Kotlin**, one of the five courses in the Agentic Data Science specialization by Pragmatic AI Labs. The course solves the same four data science problems in Kotlin, with an AI coding agent in the loop, under strict quality gates.

## Run

The Kotlin examples land with the Kotlin course pull request. Once they do, run them from this directory with:

```bash
./gradlew -q run
```

## What lives here

Nothing yet beyond this page. When the examples land: a Gradle project with a typed loader, the NA policy, the per-species profile and its gate.

## Back to the project

See the [root README](../README.md) for the full course list, the datasets, the ontology and the quality gates.

## Scene

`cd kotlin && ./gradlew -q run` runs the penguins-ols scene
(`PenguinsOls.kt`, 24 lines; helpers in `Scene.kt`/`Report.kt`):
load, drop NA, fit by two solvers, plot by species, verdict.
It reads `datasets/penguins/penguins.csv` and writes `plot.png`
at the repo root.
