#!/usr/bin/env bash
# readme-falsify.sh : CI falsifier (D46 item 5). A README with one failing step must turn readme-run.sh red,
# and a README with no bash block must be NOT MEASURED. Needs no Lean.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); T=$(mktemp -d); trap 'rm -rf "${T:?}"' EXIT
printf '# t\n```bash\ntrue\n```\n```bash\n# expect: 1\nfalse\n```\n' > "$T/ok.md"
printf '# t\n```bash\ntrue\n```\n```bash\nfalse\n```\n' > "$T/bad.md"
printf '# t\nno blocks\n' > "$T/none.md"
"$here/readme-run.sh" "$T/ok.md" "$T/r" >/dev/null 2>&1; a=$?
"$here/readme-run.sh" "$T/bad.md" "$T/r2" >/dev/null 2>&1; b=$?
"$here/readme-run.sh" "$T/none.md" "$T/r3" >/dev/null 2>&1; c=$?
echo "ok=$a (want 0) failing-step=$b (want 1) no-blocks=$c (want 2)"
[ "$a" -eq 0 ] && [ "$b" -eq 1 ] && [ "$c" -eq 2 ] && { echo "readme-falsify: GREEN"; exit 0; }
echo "readme-falsify: RED"; exit 1
