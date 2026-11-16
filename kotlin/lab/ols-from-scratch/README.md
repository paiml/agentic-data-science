# Lab: ordinary least squares from scratch (Kotlin)

You implement `fitOls` and `residualSum` in `starter/src/lab/Ols.kt` with plain
arithmetic (no library fit). The suite in `tests/` grades your code against the
course's golden OLS on the penguins data (`datasets/golden/p2.json`, key `ols`,
tolerance 1e-6), plus the refusals the lessons teach (length mismatch, constant
x, a single point).

```bash
cd kotlin/lab/ols-from-scratch
./gradlew test                     # grades starter/   (red until you finish)
./gradlew test -Pvariant=solution  # grades solution/  (green; the reference answer)
```

Needs JDK 25 (the toolchain the demo project pins).

## Recorded runs (2026-10-31, Temurin 25.0.5, Gradle 9.8.2)

| Variant  | Exit | Result                | Failing tests |
|----------|------|-----------------------|---------------|
| starter  | 1    | 8 run, 7 failed       | lengthMismatchIsRefused, residualSumOfAWrongLineIsNotZero, constantXIsRefused, singlePointIsRefused, penguinFitMatchesGolden, exactLineIsRecovered, residualsOfAnOlsFitSumToZero |
| solution | 0    | 8 run, 8 passed       | none |

`penguinsKeep342Rows` reads data only and passes on the starter by design; the
other seven fail until `fitOls` and `residualSum` are written.
