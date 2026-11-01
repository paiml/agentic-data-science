#!/usr/bin/env bash
# Determinism (ADS-DEMO-001 R-5): build a lesson's artifacts twice with <runner>; stdout.txt and plot.svg
# must hash identically. usage: determinism.sh <runner> <lesson> <lang>   (runner = lesson-artifacts.sh or a plant)
set -euo pipefail
run="$1"; lesson="$2"; lang="$3"; t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT
bash "$run" "$lesson" "$lang" "$t/a" >/dev/null; sleep 1
bash "$run" "$lesson" "$lang" "$t/b" >/dev/null
for f in stdout.txt plot.svg; do
  [ -s "$t/a/$f" ] || { echo "FAIL: run 1 produced no $f"; exit 1; }
  cmp -s "$t/a/$f" "$t/b/$f" || { echo "FAIL determinism: $f differs between two runs"; exit 1; }
done
echo "determinism OK: $lesson/$lang two runs, same hashes"
