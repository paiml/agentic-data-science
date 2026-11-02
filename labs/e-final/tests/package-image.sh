#!/usr/bin/env bash
# package-image.sh [OUT.zip] : build the Coursera custom-image zip from labs/e-final/image, byte-for-byte reproducible
# (sorted names, fixed mtime, no extra attributes), and print its sha256. README.md is not part of the image.
set -uo pipefail
here=$(cd "$(dirname "$0")/../image" && pwd); out=$(realpath -m "${1:-ads-lean-vscode-v1.zip}")
S=$(mktemp -d); trap 'rm -rf "${S:?}"' EXIT
cp -R "$here/." "$S/" && rm -f "$S/README.md" || exit 1
find "$S" -exec touch -h -d '2026-01-01 00:00:00 UTC' {} + || exit 1
rm -f "$out"
( cd "$S" && find . -type f | LC_ALL=C sort | sed 's|^\./||' | TZ=UTC zip -X -q -@ "$out" ) || exit 1
sha256sum "$out"
