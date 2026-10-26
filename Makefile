SHELL := bash
.PHONY: gate gate-datasets gate-shacl gate-r gate-julia gate-rust gate-kotlin gate-lean gate-pmat test-video lab-video

gate: gate-datasets gate-shacl gate-r gate-julia gate-lean gate-pmat

gate-datasets:
	@for d in penguins wine-quality; do (cd datasets/$$d && sha256sum -c SHA256SUMS >/dev/null && test -s LICENSE) || { echo "FAIL datasets/$$d"; exit 1; }; done; echo "datasets OK"

# SHACL via Apache Jena (no Python on the gate path); skip when no example.ttl exists yet.
gate-shacl:
	@scripts/shacl.sh

gate-pmat:
	@scripts/gate-pmat.sh

gate-rust gate-kotlin:
	@echo "$@: not yet wired (G1+)"; exit 1

gate-r:
	@scripts/gate-r.sh

gate-julia:
	@scripts/gate-julia.sh

gate-lean:
	@scripts/gate-lean.sh

# vcheck proofs: every must-PASS / must-FAIL take of the recording check (scripts/video/README.md). Ordinary tests on synthetic takes (PR job). Needs ffmpeg, ImageMagick, gcc.
test-video:
	@scripts/video/tests/run.sh

# Nightly: vcheck --gate over real takes. Nightly only (.github/workflows/video-lab.yml); never in a PR check.
lab-video:
	@scripts/video/lab.sh $(TAKES)
