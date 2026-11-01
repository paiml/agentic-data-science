#!/usr/bin/env bash
# F1: a planted change of row order in one language, an empty stdout, a landed language with no
# stdout, or an unknown language must turn parity RED; the clean set must be GREEN.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT
mkdir -p "$t/rust" "$t/julia" "$t/kotlin"
bash "$root/scripts/lesson-artifacts.sh" anscombe rust "$t/rust" >/dev/null
printf 'rust\njulia\n' > "$t/landed"
cp "$t/rust/stdout.txt" "$t/julia/stdout.txt"; cp "$t/rust/stdout.txt" "$t/kotlin/stdout.txt"
bash "$root/scripts/parity.sh" "$t" "$t/landed" >/dev/null || { echo "FAIL: clean set not green"; exit 1; }
# The committed list is checked for shape here (known languages) with the Rust bytes standing in for each
# landed language; the real cross-language comparison runs in the CI parity job on real artifacts.
mkdir -p "$t/c"
while read -r l; do [ -n "$l" ] || continue; mkdir -p "$t/c/$l"; cp "$t/rust/stdout.txt" "$t/c/$l/stdout.txt"; done < "$root/parity/anscombe.landed"
bash "$root/scripts/parity.sh" "$t/c" "$root/parity/anscombe.landed" >/dev/null || { echo "FAIL: committed landed list not green"; exit 1; }
red() { if bash "$root/scripts/parity.sh" "$t" "$t/landed" >/dev/null 2>&1; then echo "FAIL: $1 stayed green"; exit 1; fi; }
tac "$t/rust/stdout.txt" > "$t/julia/stdout.txt"; red "F1 reordered rows"
: > "$t/julia/stdout.txt"; red "empty stdout"
rm -f "${t:?}/julia/stdout.txt"; red "landed language missing"
printf 'rust\ncobol\n' > "$t/landed"; red "unknown language"
echo "F1 OK: clean GREEN; reordered, empty, missing, unknown all RED"
