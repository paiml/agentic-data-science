#!/usr/bin/env bash
# Validate every example.ttl against ontology/shapes with Apache Jena `shacl`.
# A missing validator is a FAIL (not measured), never a silent pass.
set -euo pipefail
# Jena 5 needs Java 17+; a stale JAVA_HOME (e.g. JDK 11) breaks it.
[ -d /usr/lib/jvm/java-17-openjdk-amd64 ] && export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
command -v shacl >/dev/null || { echo "FAIL: Jena 'shacl' not on PATH (not_measured)"; exit 1; }
for s in ontology/shapes/*.shape.ttl; do shacl parse --out=text "$s" >/dev/null; done
files=$(git ls-files '*/example.ttl')
[ -z "$files" ] && { echo "shapes parse OK; no example.ttl yet"; exit 0; }
for f in $files; do
  case "$f" in /*|*..*) echo "FAIL unsafe path $f"; exit 1 ;; esac
  cat ontology/ads.ttl "$f" > "${TMPDIR:-/tmp}/ads-data.ttl"
  for s in ontology/shapes/*.shape.ttl; do
    shacl validate --shapes "$s" --data "${TMPDIR:-/tmp}/ads-data.ttl" | grep -Eq 'sh:conforms +true' || { echo "FAIL $f vs $s"; exit 1; }
  done
done
for a in $(git ls-files "*artifact.ttl"); do
  case "$a" in /*|*..*) echo "FAIL unsafe path $a"; exit 1 ;; esac
  cat ontology/ads.ttl "$a" > "${TMPDIR:-/tmp}/ads-data.ttl"
  shacl validate --shapes ontology/shapes/artifact.shape.ttl --data "${TMPDIR:-/tmp}/ads-data.ttl" | grep -Eq "sh:conforms +true" || { echo "FAIL $a vs artifact shape"; exit 1; }
done
echo "shacl OK"
