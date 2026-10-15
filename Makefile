SHELL := bash
.PHONY: gate gate-datasets gate-shacl gate-r gate-julia gate-rust gate-kotlin gate-lean gate-pmat

gate: gate-datasets gate-shacl gate-pmat

gate-datasets:
	@for d in penguins wine-quality; do (cd datasets/$$d && sha256sum -c SHA256SUMS >/dev/null && test -s LICENSE) || { echo "FAIL datasets/$$d"; exit 1; }; done; echo "datasets OK"

# SHACL via Apache Jena (no Python on the gate path); skip when no example.ttl exists yet.
gate-shacl:
	@scripts/shacl.sh

gate-pmat:
	@pmat quality-gate --strict >/dev/null 2>&1 && echo "pmat OK" || { echo "pmat FAIL (or unsupported: see docs/pilots/R5.md)"; exit 1; }

gate-r gate-julia gate-rust gate-kotlin gate-lean:
	@echo "$@: not yet wired (G1+)"; exit 1
