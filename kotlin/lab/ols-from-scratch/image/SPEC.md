# Kotlin lab sandbox image

Status: built and proven offline (2026-10-31). The image runs the lab's suite with the network off.

## Contents
- Base: `debian:bookworm-slim` by digest `sha256:7ff6ba31527b9e336162fa061746c366c4b2032f4d2cff2078bea43f78efe3f8`.
- JDK: Temurin 25.0.5+8 (`adoptium/temurin25-binaries`, `OpenJDK25U-jdk_x64_linux_hotspot_25.0.5_8.tar.gz`), sha256 `68982529869257d0ee6b824ec5aa270ff8b118bb438670da0b97ebdab178d7fb`, equal to the checksum the Adoptium API lists.
- Gradle 9.8.2, sha256 `21bd5da2de49b642904077f38c0efdc7778e92b3ed0889392dca61b97e389607`, checked against `gradle-wrapper.properties` and the `.sha256` published at services.gradle.org.
- Kotlin 2.4.21 and JUnit 6.1.3 are baked into the Gradle cache at build time. Every resolved artifact is pinned by `gradle/verification-metadata.xml` (58 components), proven in a fresh Gradle home and inside the image.

## Build
Build from a clean export, never the working tree (the `.dockerignore` files in this tree are inert; Docker reads only `<context>/.dockerignore`):

```bash
git archive <commit> kotlin/lab/ols-from-scratch datasets/penguins | tar -x -C ctx
docker build -f ctx/kotlin/lab/ols-from-scratch/image/Dockerfile -t ads-kotlin-lab ctx
```

The build fails if the solution suite does not pass, if the starter suite does not exit exactly 1, or if the final `--offline` solution run fails (cache incomplete). A download or checksum failure fails the build; nothing falls back to another tag.

## Proof
```bash
docker run --rm --network none ads-kotlin-lab proof.sh
```
`proof.sh` asserts the JUnit XML, not just exit codes: starter exit 1 with 8 tests and exactly the 7 failing names listed in the lab README; solution exit 0 with 8 of 8 passing. Recorded output: `image/proof-run.txt`.

Recorded build (commit `c78ee5b`, derived image id `sha256:7f2937682614d503a262e3097be3e8b1ae55f0fba6216b19ff1fe0470737b932`): proof exit 0.

## Not run
Coursera's own lab runtime (whether it executes the suite as it runs here) is not measured.
