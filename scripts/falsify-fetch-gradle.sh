#!/usr/bin/env bash
# Poisoned-cache falsifier for fetch-gradle.sh (ads#283 quorum FAIL, 2026-11-09). Offline, fake pin.
# Plants (a) an unpacked gradle at the old cache location and (b) a tampered archive under the pin's cache key;
# the script must still hand back the VERIFIED gradle. The control runs the old trust-the-unpacked-dir logic and must be poisoned.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT
mkdir -p "$t/tree/scripts" "$t/tree/kotlin/gradle/wrapper" "$t/pkg/gradle-9.9.9/bin" "$t/cache"
printf '#!/bin/sh\necho GOOD\n' > "$t/pkg/gradle-9.9.9/bin/gradle"; chmod +x "$t/pkg/gradle-9.9.9/bin/gradle"
(cd "$t/pkg" && zip -qr "$t/g.zip" gradle-9.9.9); sha="$(sha256sum "$t/g.zip" | cut -d' ' -f1)"
cp "$root/scripts/fetch-gradle.sh" "$root/scripts/dl-cached.sh" "$t/tree/scripts/"
printf 'distributionUrl=file\\:///%s/g.zip\ndistributionSha256Sum=%s\n' "${t#/}" "$sha" > "$t/tree/kotlin/gradle/wrapper/gradle-wrapper.properties"
export ADS_DL_CACHE="$t/cache"
plant() { mkdir -p "$t/cache/gradle-$sha/bin"; printf '#!/bin/sh\necho POISON\n' > "$t/cache/gradle-$sha/bin/gradle"; chmod +x "$t/cache/gradle-$sha/bin/gradle"; printf 'tampered\n' > "$t/cache/$sha"; }
g="$(bash "$t/tree/scripts/fetch-gradle.sh" 2>/dev/null)" && [ "$("$g")" = GOOD ] || { echo "FAIL clean run did not give the verified gradle"; exit 1; }
plant
g="$(bash "$t/tree/scripts/fetch-gradle.sh" 2>/dev/null)" && [ "$("$g")" = GOOD ] || { echo "FAIL poisoned cache ran (unpacked dir or tampered archive trusted)"; exit 1; }
# control: the old logic (trust an unpacked, executable dir in the cache) is poisoned by the same plant
plant; old="$t/cache/gradle-$sha/bin/gradle"; [ -x "$old" ] && [ "$("$old")" = POISON ] || { echo "FAIL control: the plant does not poison the old logic"; exit 1; }
# the real script must not trust an unpacked dir: no cache path may appear in what it prints
grep -q 'sha256\|dl-cached.sh' "$root/scripts/fetch-gradle.sh" && ! grep -q '\-x "\$d/bin/gradle"' "$root/scripts/fetch-gradle.sh" || { echo "FAIL fetch-gradle.sh trusts an unpacked tree again"; exit 1; }
echo "falsify-fetch-gradle: PASS (poisoned archive and unpacked dir both ignored; control poisoned)"
