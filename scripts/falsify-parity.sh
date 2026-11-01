#!/usr/bin/env bash
# F1: a planted change of row order / seed in one language must turn parity RED; the clean set must be GREEN.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT
mkdir -p "$t/rust" "$t/other"
bash "$root/scripts/lesson-artifacts.sh" anscombe rust "$t/rust" >/dev/null
cp "$t/rust/stdout.txt" "$t/other/stdout.txt"
bash "$root/scripts/parity.sh" "$t" >/dev/null || { echo "FAIL: clean set not green"; exit 1; }
tac "$t/rust/stdout.txt" > "$t/other/stdout.txt"
if bash "$root/scripts/parity.sh" "$t" >/dev/null 2>&1; then echo "FAIL: F1 plant (reordered rows) stayed green"; exit 1; fi
: > "$t/other/stdout.txt"
if bash "$root/scripts/parity.sh" "$t" >/dev/null 2>&1; then echo "FAIL: empty stdout stayed green"; exit 1; fi
echo "F1 OK: clean GREEN, reordered RED, empty RED"
