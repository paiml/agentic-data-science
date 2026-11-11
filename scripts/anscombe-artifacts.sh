#!/usr/bin/env bash
# anscombe-artifacts.sh OUTDIR  (ADS-DEMO-001, ads#112)
# Runs the Kotlin Anscombe lesson twice, refuses unless both runs are byte-identical, and writes
# (stdout.txt is the parity text the lesson writes: the four set lines, byte-equal to Rust's; console.txt is what it printed, ending on the contract line.)
# stdout.txt, plot.svg and manifest.sha256 (sha256sum format) into OUTDIR. Exit 0 = artifacts written,
# 1 = runs differ or the contract line is absent, 2 = could not run.
set -euo pipefail
OUT="${1:?usage: anscombe-artifacts.sh OUTDIR}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GRADLE="${GRADLE:-$("$ROOT/scripts/fetch-gradle.sh")}"
[ -x "$GRADLE" ] || GRADLE=gradle
WORK="$(mktemp -d)"; trap 'rm -rf "${WORK:?}"' EXIT
mkdir -p "$OUT" "$WORK/a" "$WORK/b"
for r in a b; do
  (cd "$ROOT/kotlin" && "$GRADLE" --no-daemon -q -Dorg.gradle.workers.max=4 :ads-kotlin:anscombe \
    --args="data/anscombe/anscombe.csv $WORK/$r") > "$WORK/$r/console.txt" || { echo "anscombe run $r failed" >&2; exit 2; }
done
for f in stdout.txt plot.svg; do
  [ -s "$WORK/a/$f" ] || { echo "FAIL $f is absent or empty" >&2; exit 1; }
  cmp -s "$WORK/a/$f" "$WORK/b/$f" || { echo "FAIL $f differs between two runs" >&2; exit 1; }
done
tail -n 1 "$WORK/a/console.txt" | grep -Eq '^contract: .* OK$' || { echo "FAIL last line is not an OK contract line" >&2; exit 1; }
cp "$WORK/a/stdout.txt" "$WORK/a/plot.svg" "$OUT/"
(cd "$OUT" && sha256sum stdout.txt plot.svg > manifest.sha256)
echo "anscombe artifacts OK: $OUT"
