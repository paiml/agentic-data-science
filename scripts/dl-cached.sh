#!/usr/bin/env bash
# dl-cached.sh URL SHA256 DEST  (ads ANDON ci-flake, 2026-11-09)
# Put the file at URL, whose sha256 is pinned, at DEST. A copy in the runner cache ($ADS_DL_CACHE, keyed in
# CI on the pin) is used when its sha matches; the network is touched only on a miss, and the sha is verified
# after every fetch. A bad sha is never kept and never used. Exit 0 = DEST verified, 1 = sha mismatch, 2 = fetch failed.
set -euo pipefail
url="${1:?usage: dl-cached.sh URL SHA256 DEST}"; sha="${2:?}"; dest="${3:?}"
cache="${ADS_DL_CACHE:-$HOME/.cache/ads-dl}"; mkdir -p "$cache" "$(dirname "$dest")"
c="$cache/$sha"
check() { echo "$sha  $1" | sha256sum -c - >/dev/null 2>&1; }
get() { if command -v curl >/dev/null; then curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 -o "$2" "$1"; else local i; for i in 1 2 3 4 5; do java "$(dirname "$0")/Fetch.java" "$1" "$2" && return 0; sleep 5; done; return 1; fi; }
if [ -f "$c" ] && check "$c"; then echo "dl-cached: hit $sha" >&2
else
  rm -f "${c:?}"
  get "$url" "$c.part" || { rm -f "${c:?}.part"; echo "dl-cached: fetch failed $url" >&2; exit 2; }
  if ! check "$c.part"; then rm -f "${c:?}.part"; echo "dl-cached: sha256 mismatch for $url" >&2; exit 1; fi
  mv "$c.part" "$c"; echo "dl-cached: fetched $sha" >&2
fi
cp "$c" "$dest"; check "$dest" || { echo "dl-cached: dest sha256 mismatch" >&2; exit 1; }
