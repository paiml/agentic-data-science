#!/usr/bin/env bash
# fetch-gradle.sh : print the path of a Gradle binary for the pin in kotlin/gradle/wrapper/gradle-wrapper.properties
# (url and sha256 are read from there, the one source). Only the ARCHIVE is cached; dl-cached.sh verifies its sha256 on
# every use, and it is unpacked fresh into a new temp dir each time, so an unpacked tree in a cache is never trusted.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; p="$root/kotlin/gradle/wrapper/gradle-wrapper.properties"
url="$(sed -n 's/^distributionUrl=//p' "$p" | sed 's/\\//g')"; sha="$(sed -n 's/^distributionSha256Sum=//p' "$p")"
[ -n "$url" ] && [ -n "$sha" ] || { echo "fetch-gradle: pin missing in $p" >&2; exit 2; }
v="$(echo "$url" | sed -n "s/.*gradle-\(.*\)-bin.zip/\1/p")"
d="$(mktemp -d)"; z="$d/gradle.zip"
bash "$root/scripts/dl-cached.sh" "$url" "$sha" "$z" >&2 || bash "$root/scripts/dl-cached.sh" "https://github.com/gradle/gradle-distributions/releases/download/v$v/gradle-$v-bin.zip" "$sha" "$z" >&2
(cd "$d" && if command -v unzip >/dev/null; then unzip -q gradle.zip; else jar xf gradle.zip; fi)
chmod +x "$d"/gradle-*/bin/gradle
echo "$(echo "$d"/gradle-*)/bin/gradle"
