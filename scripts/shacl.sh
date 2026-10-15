#!/usr/bin/env bash
# Validate every example.ttl against ontology/shapes with Apache Jena `shacl`.
# A missing validator is a FAIL (not measured), never a silent pass.
set -euo pipefail
command -v shacl >/dev/null || { echo "FAIL: Jena 'shacl' not on PATH (not_measured)"; exit 1; }
for s in ontology/shapes/*.shape.ttl; do shacl parse --out=text "$s" >/dev/null; done
files=$(git ls-files '*/example.ttl')
[ -z "$files" ] && { echo "shapes parse OK; no example.ttl yet"; exit 0; }
for f in $files; do
  cat ontology/ads.ttl "$f" > "${TMPDIR:-/tmp}/ads-data.ttl"
  for s in ontology/shapes/*.shape.ttl; do
    shacl validate --shapes "$s" --data "${TMPDIR:-/tmp}/ads-data.ttl" | grep -q 'conforms true' || { echo "FAIL $f vs $s"; exit 1; }
  done
done
echo "shacl OK"
