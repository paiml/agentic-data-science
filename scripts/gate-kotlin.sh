#!/usr/bin/env bash
# Kotlin gate: tests, Kover LINE=100 + BRANCH>=95, ktlint, detekt (maxIssues 0), pmat complexity/satd/duplicates.
# pmat entropy reads only Rust/Ruchy, dead-code only Cargo crates: not measured on Kotlin (measured 2026-10-22: pmat quality-gate -p kotlin fails entropy; duplicates counts byte-identical files only).
set -euo pipefail
cd "$(dirname "$0")/../kotlin"
command -v gradle >/dev/null || export PATH="$HOME/.local/opt/gradle-8.14.3/bin:$PATH"
command -v gradle >/dev/null || { echo "FAIL: gradle not on PATH (not_measured)"; exit 1; }
# Gradle toolchain autodetection misses the runners JDK: hand it JAVA_HOME (the workflow installs a pinned JDK 17), else the java on PATH.
jhome="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
echo "gate-kotlin: java=$(command -v java) jhome=$jhome JAVA_HOME=${JAVA_HOME:-unset} javac=$(ls "$jhome/bin/javac" 2>&1)" >&2
gradle -Dorg.gradle.java.installations.paths="$jhome" --no-daemon --no-configuration-cache :ads-kotlin:test :ads-kotlin:koverVerify :ads-kotlin:ktlintCheck :ads-kotlin:detekt
pmat quality-gate -p . --checks complexity,satd,duplicates --fail-on-violation -q
echo "gate-kotlin OK"
