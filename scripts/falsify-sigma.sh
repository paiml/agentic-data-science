#!/bin/bash
# Falsifier for contracts/ontology.yaml: the real Σ must pass `pv lint --gate sigma` + `pv ontology tbox`,
# and a Σ with a planted bad class (a role whose range names a concept Σ does not declare) must FAIL both.
set -u
R=$(cd "$(dirname "$0")/.." && pwd); T=$(mktemp -d)
pv lint --gate sigma "$R/contracts" >/dev/null 2>&1 || { echo "FAIL: real Sigma does not pass sigma gate"; exit 1; }
pv ontology tbox "$R/contracts/ontology.yaml" >/dev/null 2>&1 || { echo "FAIL: real Sigma does not pass tbox"; exit 1; }
mkdir "$T/contracts"; cp "$R"/contracts/*.yaml "$T/contracts/"
cat >> "$T/contracts/ontology.yaml" <<'Y'
Y
sed -i 's/range: Artifact, symmetric: false, acyclic: false, doc: "the example emits/range: NoSuchClass, symmetric: false, acyclic: false, doc: "the example emits/' "$T/contracts/ontology.yaml"
if pv lint --gate sigma "$T/contracts" >/dev/null 2>&1 && pv ontology tbox "$T/contracts/ontology.yaml" >/dev/null 2>&1; then
  echo "FAIL: planted bad class was accepted"; exit 1; fi
echo "falsify OK: real Sigma passes sigma+tbox; planted NoSuchClass range is refused"
