#!/usr/bin/env bash
# Hero image (ADS-DEMO-001 R-9, F5): build it from the landed plots, then compare with the committed copy.
# usage: hero.sh build <artifacts-dir> <out-dir>   writes hero.svg + hero.sha256 (sha256 of hero.svg)
#        hero.sh check <artifacts-dir>            RED if assets/hero.svg or its sha256 is missing, stale, or unreferenced by README.md
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; mode="$1"; arts="$(cd "$2" && pwd)"
landed="$root/parity/anscombe.landed"
build() { mkdir -p "$1"; set -- "$(cd "$1" && pwd)"; (cd "$root/rust/ads-rust" && cargo run -q --locked --example hero -- "$arts" "$landed" "$1/hero.svg" >/dev/null); (cd "$1" && sha256sum hero.svg | cut -d' ' -f1 > hero.sha256); }
case "$mode" in
  build) build "$3"; echo "hero OK: $3/hero.svg $(cat "$3/hero.sha256")";;
  check)
    for f in assets/hero.svg assets/hero.sha256; do [ -s "$root/$f" ] || { echo "FAIL (F5): $f missing"; exit 1; }; done
    t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT; build "$t"
    [ "$(cat "$t/hero.sha256")" = "$(cat "$root/assets/hero.sha256")" ] || { echo "FAIL (F5): assets/hero.sha256 is stale ($(cat "$t/hero.sha256") expected)"; exit 1; }
    cmp -s "$t/hero.svg" "$root/assets/hero.svg" || { echo "FAIL (F5): assets/hero.svg is stale"; exit 1; }
    ( cd "$root/assets" && sha256sum -c <(printf '%s  hero.svg\n' "$(cat hero.sha256)") >/dev/null ) || { echo "FAIL (F5): hero.svg does not match its sha256"; exit 1; }
    /usr/bin/grep -q '(assets/hero.svg)' "$root/README.md" || { echo "FAIL (F5): README.md does not show assets/hero.svg"; exit 1; }
    echo "hero check OK";;
  *) echo "usage: hero.sh build|check"; exit 2;;
esac
