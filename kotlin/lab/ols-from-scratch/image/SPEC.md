# Kotlin lab sandbox image: spec (NOT BUILT)

Status: spec only. Build waits for a quorum round (two non-author lanes, as for the Julia image) because it pulls a base image, a JDK tarball and a Gradle zip.

- Base: debian:bookworm-slim by digest (same as ads-julia-render).
- JDK: Temurin 25.0.5 (the toolchain the demo project pins), sha256 68982529869257d0ee6b824ec5aa270ff8b118bb438670da0b97ebdab178d7fb. Asset: adoptium/temurin25-binaries jdk-25.0.5+8 OpenJDK25U-jdk_x64_linux_hotspot_25.0.5_8.tar.gz (checksum from api.adoptium.net equals the sha above).
- Gradle: 9.8.2, sha256 21bd5da2de49b642904077f38c0efdc7778e92b3ed0889392dca61b97e389607 (from gradle-wrapper.properties).
- Kotlin 2.4.21 / JUnit 6.1.3: baked into the Gradle cache at build; run `--offline --network none`.
- Proof owed after build: starter exit 1 (7/8 fail) and solution exit 0 (8/8) inside the image with the network off; base and derived digests recorded beside the receipt.
- Not run: Coursera's own lab runtime (spec Δ5). rmedia-92's agentic-lean path does not exist yet (blocked at Create-private-session start date), so this follows the Julia precedent.
