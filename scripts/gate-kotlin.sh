#!/usr/bin/env bash
# Kotlin gate: tests, Kover LINE=100 + BRANCH>=95, ktlint, detekt (maxIssues 0), pmat complexity/satd/duplicates.
# pmat entropy reads only Rust/Ruchy, dead-code only Cargo crates: not measured on Kotlin (state.md R5).
set -euo pipefail
cd "$(dirname "$0")/../kotlin"
command -v gradle >/dev/null || export PATH="$HOME/.local/opt/gradle-8.14.3/bin:$PATH"
command -v gradle >/dev/null || { echo "FAIL: gradle not on PATH (not_measured)"; exit 1; }
gradle --no-daemon --no-configuration-cache :ads-kotlin:test :ads-kotlin:koverVerify :ads-kotlin:ktlintCheck :ads-kotlin:detekt
pmat quality-gate -p . --checks complexity,satd,duplicates --fail-on-violation -q
echo "gate-kotlin OK"
