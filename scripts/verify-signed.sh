#!/usr/bin/env bash
# Verify a lesson's keyless sigstore bundles (ADS-DEMO-001 R-2): each of stdout.txt, plot.svg and manifest.sha256
# must have a <file>.sigstore.json bundle signed by this repo's ci workflow, and the manifest must match the files.
# usage: verify-signed.sh <dir> <repo owner/name>
set -euo pipefail
d="$1"; repo="$2"
(cd "$d" && sha256sum -c manifest.sha256 >/dev/null) || { echo "FAIL: manifest does not match the files"; exit 1; }
for f in stdout.txt plot.svg manifest.sha256; do
  [ -s "$d/$f.sigstore.json" ] || { echo "FAIL: no bundle for $f"; exit 1; }
  cosign verify-blob --bundle "$d/$f.sigstore.json" \
    --certificate-identity-regexp "^https://github.com/$repo/\.github/workflows/ci\.yml@" \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com "$d/$f" >/dev/null 2>&1 \
    || { echo "FAIL: signature on $f does not verify"; exit 1; }
done
echo "signed OK: $d"
