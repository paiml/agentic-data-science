SHELL := bash
.SUFFIXES:
.DELETE_ON_ERROR:
.PHONY: gate gate-datasets gate-shacl gate-r gate-julia gate-rust gate-kotlin gate-lean gate-pmat

gate: gate-parity gate-datasets gate-shacl gate-r gate-julia gate-rust gate-kotlin gate-lean gate-pmat

gate-datasets:
	@for d in datasets/penguins datasets/wine-quality data/anscombe; do (cd $$d && sha256sum -c SHA256SUMS >/dev/null && test -s LICENSE) || { echo "FAIL $$d"; exit 1; }; done; echo "datasets OK"

# SHACL via Apache Jena (no Python on the gate path); skip when no example.ttl exists yet.
gate-shacl:
	@scripts/shacl.sh

gate-pmat:
	@scripts/gate-pmat.sh

gate-r:
	@scripts/gate-r.sh

gate-julia:
	@scripts/gate-julia.sh $(JULIA_PARTS)

gate-kotlin:
	@scripts/gate-kotlin.sh

gate-lean:
	@scripts/gate-lean.sh

gate-rust:
	@scripts/gate-rust.sh

.PHONY: gate-parity
gate-parity:
	@scripts/falsify-parity.sh
