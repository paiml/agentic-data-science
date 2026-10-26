SHELL := bash
.PHONY: gate gate-datasets gate-shacl gate-shacl-negative gate-r gate-julia gate-rust gate-kotlin gate-lean lean-scan gate-pmat

gate: gate-datasets gate-shacl gate-r gate-julia gate-lean gate-pmat

gate-datasets:
	@for d in penguins wine-quality; do (cd datasets/$$d && sha256sum -c SHA256SUMS >/dev/null && test -s LICENSE) || { echo "FAIL datasets/$$d"; exit 1; }; done; echo "datasets OK"

# SHACL via Apache Jena (no Python on the gate path); skip when no example.ttl exists yet.
gate-shacl:
	@scripts/shacl.sh

gate-shacl-negative:
	@scripts/shacl-negative.sh

gate-pmat:
	@scripts/gate-pmat.sh

gate-rust gate-kotlin:
	@echo "$@: not yet wired (G1+)"; exit 1

gate-r:
	@scripts/gate-r.sh

gate-julia:
	@scripts/gate-julia.sh


gate-lean:
	scripts/gate-lean.sh

# Stage 2 of the Lean gate, also typed on camera: grep's own output (none when clean).
lean-scan:
	cd lean/AgenticDS && { grep -rn --include='*.lean' -E '\b(sorry|admit)\b|native_decide|TODO|FIXME|HACK|XXX' AgenticDS.lean AgenticDS AgenticDSTest scripts; [ $$? -eq 1 ]; }
	@echo "scan: no markers in $$(find lean/AgenticDS/AgenticDS.lean lean/AgenticDS/AgenticDS lean/AgenticDS/AgenticDSTest lean/AgenticDS/scripts -name '*.lean' | wc -l) Lean files"
