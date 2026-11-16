#!/usr/bin/env bash
# F2: a timestamp injected into the plot must turn the determinism job RED; the clean runner must be GREEN.
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"; t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT
bash "$root/determinism.sh" "$root/lesson-artifacts.sh" anscombe rust >/dev/null || { echo "FAIL: clean runner not green"; exit 1; }
cat > "$t/plant.sh" <<P
#!/usr/bin/env bash
set -euo pipefail
bash "$root/lesson-artifacts.sh" "\$1" "\$2" "\$3" >/dev/null
printf '<!-- %s -->\n' "\$(date +%s%N)" >> "\$3/plot.svg"
P
if bash "$root/determinism.sh" "$t/plant.sh" anscombe rust >/dev/null 2>&1; then echo "FAIL: F2 timestamp plant stayed green"; exit 1; fi
printf '#!/usr/bin/env bash\nmkdir -p "$3"; : > "$3/stdout.txt"; : > "$3/plot.svg"\n' > "$t/empty.sh"
if bash "$root/determinism.sh" "$t/empty.sh" anscombe rust >/dev/null 2>&1; then echo "FAIL: empty artifacts stayed green"; exit 1; fi
echo "F2 OK: clean GREEN; timestamp plant RED; empty artifacts RED"
# verify-signed.sh must refuse a missing bundle and a manifest that does not match (both fail before cosign runs).
bash "$root/lesson-artifacts.sh" anscombe rust "$t/art" >/dev/null
if bash "$root/verify-signed.sh" "$t/art" o/r >/dev/null 2>&1; then echo "FAIL: unsigned artifacts verified"; exit 1; fi
echo x >> "$t/art/stdout.txt"
out=$(bash "$root/verify-signed.sh" "$t/art" o/r 2>&1 || true)
case "$out" in *"manifest does not match"*) ;; *) echo "FAIL: tampered stdout.txt not caught: $out"; exit 1;; esac
echo "verify-signed OK: unsigned RED, tampered RED"
