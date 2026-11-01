# ADS-DEMO-001 R-7: Anscombe (R) image. Base by digest (rocker/r-ver 4.6.1), packages from the pinned
# Posit snapshot via scripts/r-deps.sh. Build context: a clean `git archive` export of the repo root.
FROM rocker/r-ver@sha256:bafb3b9a72791eeeb810f0bc0472e74c7f4939b20b46c96cb7ebc6838b6a25ef
COPY scripts/r-deps.sh scripts/r-pins.txt /w/scripts/
RUN bash /w/scripts/r-deps.sh /opt/rlib
ENV R_LIBS=/opt/rlib
COPY r/agenticds /w/r/agenticds
RUN R CMD INSTALL --no-docs /w/r/agenticds
COPY data /w/data
COPY lessons/anscombe /w/lessons/anscombe
WORKDIR /w
