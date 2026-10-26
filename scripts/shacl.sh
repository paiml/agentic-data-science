#!/usr/bin/env bash
# Validate every example.ttl against ontology/shapes with Apache Jena `shacl`.
# A missing validator is a FAIL (not measured), never a silent pass.
# Each validation echoes Jena's own `sh:conforms true` line; the task
# exits non-zero unless every report says so (the CLI itself exits 0 on findings).
set -euo pipefail
# Jena 5 needs Java 17+; a stale JAVA_HOME (e.g. JDK 11) breaks it.
[ -d /usr/lib/jvm/java-17-openjdk-amd64 ] && export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
command -v shacl >/dev/null || { echo "FAIL: Jena 'shacl' not on PATH (not_measured)"; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "${tmp:?}"' EXIT

# conforms SHAPES DATA LABEL: print Jena's sh:conforms line; fail unless true.
conforms() {
  local report
  report=$(shacl validate --shapes "$1" --data "$2")
  if line=$(printf '%s\n' "$report" | grep -E 'sh:conforms +true'); then
    echo "$line"
  else
    printf '%s\n' "$report"
    echo "FAIL $3"
    return 1
  fi
}

# SHACL_DATA_FILES overrides the tracked list only for the negative control (SHACL_NEGATIVE_CONTROL=1); a stray variable cannot shrink the gate.
[ "${SHACL_NEGATIVE_CONTROL:-}" = 1 ] || unset SHACL_DATA_FILES
files=${SHACL_DATA_FILES:-$(git ls-files '*/example.ttl')}
for s in ontology/shapes/*.shape.ttl; do shacl parse --out=text "$s" >/dev/null; done
[ -z "$files" ] && { echo "shapes parse OK; no example.ttl yet"; exit 0; }
for f in $files; do
  cat ontology/ads.ttl "$f" > "$tmp/ads-data.ttl"
  for s in ontology/shapes/*.shape.ttl; do
    conforms "$s" "$tmp/ads-data.ttl" "$f vs $s"
  done
done
if [ -z "${SHACL_DATA_FILES:-}" ]; then
  for a in $(git ls-files "*artifact.ttl"); do
    cat ontology/ads.ttl "$a" > "$tmp/ads-data.ttl"
    conforms ontology/shapes/artifact.shape.ttl "$tmp/ads-data.ttl" "$a vs artifact shape"
  done
fi
echo "shacl OK"
