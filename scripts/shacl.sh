#!/usr/bin/env bash
# Validate every example.ttl against ontology/shapes with Apache Jena `shacl`.
# A missing validator is a FAIL (not measured), never a silent pass.
set -euo pipefail
# Jena 5 needs Java 17+; a stale JAVA_HOME (e.g. JDK 11) breaks it.
[ -d /usr/lib/jvm/java-17-openjdk-amd64 ] && export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
command -v shacl >/dev/null || { echo "FAIL: Jena 'shacl' not on PATH (not_measured)"; exit 1; }
for s in ontology/shapes/*.shape.ttl; do shacl parse --out=text "$s" >/dev/null; done
# Print Jena's own sh:conforms line; anything but true fails.
conforms() { # shapes data label
  local r
  r=$(shacl validate --shapes "$1" --data "$2") || return 1
  echo "$r" | grep -E 'sh:conforms +true' | sed "s|^|$3: |"
}
files=$(git ls-files '*/example.ttl')
[ -z "$files" ] && { echo "shapes parse OK; no example.ttl yet"; exit 0; }
for f in $files; do
  case "$f" in /*|*..*) echo "FAIL unsafe path $f"; exit 1 ;; esac
  cat ontology/ads.ttl "$f" > "${TMPDIR:-/tmp}/ads-data.ttl"
  for s in ontology/shapes/*.shape.ttl; do
    conforms "$s" "${TMPDIR:-/tmp}/ads-data.ttl" "$f" || { echo "FAIL $f vs $s"; exit 1; }
  done
done
for a in $(git ls-files "*artifact.ttl"); do
  case "$a" in /*|*..*) echo "FAIL unsafe path $a"; exit 1 ;; esac
  cat ontology/ads.ttl "$a" > "${TMPDIR:-/tmp}/ads-data.ttl"
  conforms ontology/shapes/artifact.shape.ttl "${TMPDIR:-/tmp}/ads-data.ttl" "$a" || { echo "FAIL $a vs artifact shape"; exit 1; }
done
echo "shacl OK"
