#!/usr/bin/env bash
# R-5: two runs give identical hashes; stdout ends in the contract line.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
a="$(mktemp -d)"; b="$(mktemp -d)"; trap 'rm -rf "${a:?}" "${b:?}"' EXIT
"$here/lesson.sh" "$a"; "$here/lesson.sh" "$b"
cmp "$a/manifest.sha256" "$b/manifest.sha256"
test "$(wc -l < "$a/stdout.txt")" = 4
cat "$a/manifest.sha256"; echo "determinism: OK"
