#!/usr/bin/env bash
# Shared setup for the Kotlin terminal demos: pin the toolchain, run from the repo root.
# The recorded shell has PATH=/usr/bin:/bin only, so tools outside it are found by probing known install dirs.
set -euo pipefail
ADS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ADS_ROOT
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
tools=""
for d in /opt/gradle/bin /home/noah/.cargo/bin /home/noah/.local/bin /home/noah/.juliaup/bin /home/noah/.elan/bin; do
  [ -d "$d" ] && tools="${tools:+$tools:}$d"
done
export PATH="$JAVA_HOME/bin:${tools:+$tools:}/usr/bin:/bin"
cd "$ADS_ROOT"
