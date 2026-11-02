# ADS Lean lab image, M1-M2 demos (see SPEC.md). NOT PUBLISHED. Build context = a clean export, never the working tree:
#   git archive <sha> lean/lab/m1-m2-demos | tar -x -C ctx ; docker build -f ctx/lean/lab/m1-m2-demos/image/Dockerfile ctx
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git xz-utils && rm -rf /var/lib/apt/lists/*
ENV ELAN_HOME=/opt/elan PATH=/opt/elan/bin:$PATH
# elan installer: pin the version in ELAN_REF before the first real build and record its sha256 in SPEC.md (NOT YET RECORDED).
ARG ELAN_REF=v4.1.2
RUN curl -fsSL https://raw.githubusercontent.com/leanprover/elan/${ELAN_REF}/elan-init.sh | sh -s -- -y --default-toolchain none
COPY lean/lab/m1-m2-demos/tree/ /w/
WORKDIR /w/lean/AgenticDS
# toolchain comes from lean-toolchain; mathlib from lake-manifest.json (rev e91b1280); cache get + build need the network, BUILD time only.
RUN lake exe cache get && lake build
COPY lean/lab/m1-m2-demos/image/proof.sh /usr/local/bin/proof.sh
# Proof (network none): docker run --rm --network none IMAGE proof.sh
