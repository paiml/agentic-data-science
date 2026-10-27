#!/usr/bin/env bash
# Kotlin gate: tests, shacl verify tasks (Jena), Kover LINE=100 + BRANCH>=95, ktlint,
# detekt 2.x (any finding fails), pmat complexity/satd/duplicates.
# pmat entropy reads only Rust/Ruchy, dead-code only Cargo
# crates: not measured on Kotlin (measured 2026-10-22:
# quality-gate -p kotlin fails entropy; duplicates counts
# byte-identical files only).
set -euo pipefail
cd "$(dirname "$0")/../kotlin"
gbin="$HOME/.local/opt/gradle-9.8.2/bin"
command -v gradle >/dev/null || export PATH="$gbin:$PATH"
command -v gradle >/dev/null || {
  echo "FAIL: gradle not on PATH (not_measured)"
  exit 1
}
# Toolchain autodetection misses the runners JDK: hand it
# JAVA_HOME (the workflow pins JDK 25), else java on PATH.
java_home() {
  local j
  j=$(readlink -f "$(command -v java)")
  dirname "$(dirname "$j")"
}
jhome="${JAVA_HOME:-$(java_home)}"
echo "gate-kotlin: jhome=$jhome" >&2
echo "javac=$(ls "$jhome/bin/javac" 2>&1)" >&2
opt=-Dorg.gradle.java.installations.paths
args=(--no-daemon --no-configuration-cache)
args+=(:ads-kotlin:test :ads-kotlin:koverVerify)
args+=(:ads-kotlin:ktlintCheck :ads-kotlin:detekt)
args+=(:ads-kotlin:verifyShaclAll)
args+=(:ads-kotlin:koverLog :ads-kotlin:koverLogBranch)
gradle "$opt=$jhome" --console=plain "${args[@]}"
checks=complexity,satd,duplicates
flags=(--fail-on-violation -q)
pmat quality-gate -p . --checks "$checks" "${flags[@]}"
echo "gate-kotlin OK"
