#!/usr/bin/env bash
# Validate every example.ttl against ontology/shapes with Apache Jena `shacl`.
# Jena's CLI exits 0 even on a violation, so this gate fails unless the
# report says `sh:conforms true`, and it echoes Jena's own report line.
# A missing validator is a FAIL (not measured), never a silent pass.
# SHACL_EXAMPLES overrides the file list (negative control only).
set -euo pipefail
# Jena 5 needs Java 17+; a stale JAVA_HOME (e.g. JDK 11) breaks it.
[ -d /usr/lib/jvm/java-17-openjdk-amd64 ] && export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
command -v shacl >/dev/null || { echo "FAIL: Jena 'shacl' not on PATH (not_measured)"; exit 1; }
for s in ontology/shapes/*.shape.ttl; do shacl parse --out=text "$s" >/dev/null; done
files="${SHACL_EXAMPLES:-$(git ls-files '*/example.ttl')}"
[ -z "$files" ] && { echo "shapes parse OK; no example.ttl yet"; exit 0; }
data="$(mktemp --suffix=.ttl)"
trap 'rm -f "$data"' EXIT
line=""
check() { # shape, data file, label
  local report
  report=$(shacl validate --shapes "$1" --data "$data")
  line=$(grep -E 'sh:conforms +true' <<<"$report") || { echo "FAIL $2 vs $1"; echo "$report"; exit 1; }
}
for f in $files; do
  cat ontology/ads.ttl "$f" > "$data"
  for s in ontology/shapes/*.shape.ttl; do check "$s" "$f"; done
done
for a in $(git ls-files "*artifact.ttl"); do
  [ -z "${SHACL_EXAMPLES:-}" ] || break
  cat ontology/ads.ttl "$a" > "$data"
  check ontology/shapes/artifact.shape.ttl "$a"
done
echo "$line"
