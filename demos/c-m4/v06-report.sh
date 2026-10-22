#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M4 video 6: report_ttl writes the Turtle artifact; Jena SHACL validates it
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
[ -d /usr/lib/jvm/java-17-openjdk-amd64 ] && export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$HOME/.local/bin:$PATH"
out="$(mktemp -d)"
trap 'rm -rf -- "${out:?}"' EXIT
Rscript -e 'library(agenticds)
res <- pipeline_wine("datasets/wine-quality/winequality-red.csv", "datasets/wine-quality/winequality-white.csv")
report_ttl(res, file.path(commandArgs(TRUE)[1], "artifact.ttl"))' "$out"
cat "$out/artifact.ttl"
grep -q 'a ads:Artifact' "$out/artifact.ttl"
cat ontology/ads.ttl "$out/artifact.ttl" > "$out/data.ttl"
shacl validate --shapes ontology/shapes/artifact.shape.ttl --data "$out/data.ttl" | grep -E 'sh:conforms'
shacl validate --shapes ontology/shapes/artifact.shape.ttl --data "$out/data.ttl" > "$out/ok.report"
grep -Eq 'sh:conforms +true' "$out/ok.report"
grep -v 'ads:generatedBy' "$out/artifact.ttl" | cat ontology/ads.ttl - > "$out/bad.ttl"
echo "broken copy (no generatedBy):"
shacl validate --shapes ontology/shapes/artifact.shape.ttl --data "$out/bad.ttl" > "$out/bad.report"
grep -E 'sh:conforms|sh:resultPath' "$out/bad.report"
grep -Eq 'sh:conforms +false' "$out/bad.report"
grep -Eq 'sh:resultPath +ads:generatedBy' "$out/bad.report"
echo "contract: c-m4 artifact conforms; a broken copy is refused OK"
