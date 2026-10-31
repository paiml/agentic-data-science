# Kotlin lab sandbox image: spec (NOT BUILT)

Status: spec only. Build waits for a quorum round (two non-author lanes, as for the Julia image) because it pulls a base image, a JDK tarball and a Gradle zip.

- Base: debian:bookworm-slim by digest (same as ads-julia-render).
- JDK: Temurin 25.0.5 (the toolchain the demo project pins), sha256 68982529869257d0ee6b824ec5aa270ff8b118bb438670da0b97ebdab178d7fb. Asset: adoptium/temurin25-binaries jdk-25.0.5+8 OpenJDK25U-jdk_x64_linux_hotspot_25.0.5_8.tar.gz (checksum from api.adoptium.net equals the sha above).
- Gradle: 9.8.2, sha256 21bd5da2de49b642904077f38c0efdc7778e92b3ed0889392dca61b97e389607 (from gradle-wrapper.properties).
- Kotlin 2.4.21 / JUnit 6.1.3: baked into the Gradle cache at build; run `--offline --network none`.
- Proof owed after build: starter exit 1 (7/8 fail) and solution exit 0 (8/8) inside the image with the network off; base and derived digests recorded beside the receipt.
- Not run: Coursera's own lab runtime (spec Δ5). rmedia-92's agentic-lean path does not exist yet (blocked at Create-private-session start date), so this follows the Julia precedent.

## Conditions from the quorum (2 Opus 5.5 lanes, both B; receipt /mnt/nvme-raid0/tmp-de/lab-c04/receipt-image-quorum.md)
Applied in the Dockerfile: no `|| true` (solution must pass, starter must exit exactly 1), datasets copied to /w/datasets, build from a clean `git archive` context (never the working tree) with a .dockerignore, a final `--offline` solution run proves the cache complete, Gradle sha cross-checked against services.gradle.org, java version matched as `25.0.5+8`.
Owed at build: record the base digest before building and the derived image digest after; offline smoke (network none) before recording; a pull or download failure is not_measured with no tag switch; proof.sh asserts the JUnit XML (8 tests; exactly the 7 failing names in README for starter; 8/8 for solution), because exit codes alone also match an offline resolution failure.
Open follow-up (lane 2 point 4): no Gradle dependency verification metadata / lockfile yet (Julia has a committed Manifest). At build, record the sha256 of every resolved artifact in the derived-image receipt; adding `verification-metadata.xml` is a ticket.

## BUILT 2026-10-31 (quorum PASS: receipt /mnt/nvme-raid0/tmp-de/lab-c04/receipt-image-quorum.md)
Built from `git archive f80e212`. Base debian@sha256:7ff6ba31527b9e336162fa061746c366c4b2032f4d2cff2078bea43f78efe3f8. Derived image 127.0.0.1:5000/ads-kotlin-lab:1 = sha256:df9388c09d9968690b3e47340eb3134f1334e7c33792d70c6445bec9756da973.
Proof with `docker run --rm --network none ... proof.sh`: exit 0, "starter exit 1 (7/8 named failures), solution exit 0 (8/8) OK" (log image-proof.log). Correction: the two .dockerignore files are inert (Docker reads <context>/.dockerignore); the clean git-archive context is what excludes build output.
Still owed: Gradle dependency verification metadata; Coursera lab runtime (not run).
