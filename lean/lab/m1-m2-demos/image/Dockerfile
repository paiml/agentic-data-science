# ADS Lean lab image, M1-M2 demos (see SPEC.md). NOT PUBLISHED. Build context = a clean export, never the working tree:
#   git archive <sha> lean/lab/m1-m2-demos | tar -x -C ctx ; docker build -f ctx/lean/lab/m1-m2-demos/image/Dockerfile ctx
# base: debian:bookworm-slim by digest (same digest the Kotlin lab image uses, recorded 2026-10-27)
FROM debian@sha256:7ff6ba31527b9e336162fa061746c366c4b2032f4d2cff2078bea43f78efe3f8
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git xz-utils && rm -rf /var/lib/apt/lists/*
ENV ELAN_HOME=/opt/elan PATH=/opt/elan/bin:$PATH
# elan 4.2.4 x86_64 release archive; sha256 equals the digest the GitHub release API lists for that asset.
ARG ELAN_SHA=42b94d4244e8353142c456ec0e4ca6528fd898a6c604d4059f494e706e431f63
RUN curl -fsSL -o /tmp/elan.tgz https://github.com/leanprover/elan/releases/download/v4.2.4/elan-x86_64-unknown-linux-gnu.tar.gz \
 && echo "$ELAN_SHA  /tmp/elan.tgz" | sha256sum -c - && tar -xzf /tmp/elan.tgz -C /tmp && /tmp/elan-init -y --no-modify-path --default-toolchain none && rm -f /tmp/elan.tgz /tmp/elan-init
COPY lean/lab/m1-m2-demos/tree/ /w/
WORKDIR /w/lean/AgenticDS
# toolchain from lean-toolchain; mathlib rev from lake-manifest.json. cache get + build need the network, BUILD time only.
RUN lake exe cache get && lake build
COPY lean/lab/m1-m2-demos/image/proof.sh /usr/local/bin/proof.sh
# Proof (network none): docker run --rm --network none IMAGE proof.sh
