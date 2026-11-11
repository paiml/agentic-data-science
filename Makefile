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
	@scripts/falsify-gate-lean-progress.sh
	@scripts/falsify-result-cache.sh
	@scripts/gate-lean.sh

gate-rust:
	@scripts/gate-rust.sh

.PHONY: gate-parity
gate-parity:
	@scripts/falsify-parity.sh
	@scripts/falsify-dl-cached.sh
	@scripts/falsify-fetch-gradle.sh
	@scripts/falsify-determinism.sh

.PHONY: gate-hero
# usage: make gate-hero ARTS=<dir holding <lang>/plot.svg for every landed language except rust>
gate-hero:
	@scripts/falsify-hero.sh "$(ARTS)"

# Marker scan alone, for course demos. Not a gate: `make gate` does not run it.
.PHONY: lean-scan falsify-lean-scan
lean-scan:
	@scripts/lean-scan.sh

falsify-lean-scan:
	@scripts/falsify-lean-scan.sh

# RMV-001 v0.9.9 §15.8 (D48): local lab preview. Builds the lab image from labs/<LAB>/image at HEAD, serves the IDE on 127.0.0.1:$(PORT), grades in-container, writes out/lab-preview/<COURSE>/<LAB>/card.{md,json}.
.PHONY: lab-preview falsify-lab-preview
lab-preview:
	@test -n "$(COURSE)" -a -n "$(LAB)" || { echo "usage: make lab-preview COURSE=c05 LAB=e-final"; exit 2; }
	@bash labs/$(LAB)/tests/lab-preview.sh $(COURSE) $(LAB)
falsify-lab-preview:
	@bash labs/e-final/tests/falsify-image-digest.sh
	@bash labs/e-final/tests/falsify-lab-preview.sh
	@bash labs/e-final/tests/falsify-exit-codes.sh

# End-to-end falsifiers for the gate-lean result cache: sampled arms, then all arms off/cold/warm (real Lean, needs `lake build`; CI runs it after gate-lean).
.PHONY: falsify-fn-cov-cache
falsify-fn-cov-cache:
	@scripts/falsify-fn-cov-cache.sh
	@scripts/falsify-fn-cov-equality.sh
