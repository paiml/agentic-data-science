#!/usr/bin/env bash
# Install the pinned R gate tools into $1 from a dated CRAN snapshot
# (Posit Package Manager, noble binaries), then fail unless every
# version in scripts/r-pins.txt matches.
set -euo pipefail
lib="${1:?usage: r-deps.sh LIBDIR}"
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$lib"
export R_LIBS="$lib"
tmp="$(mktemp)"
cat > "$tmp" <<'RS'
a <- commandArgs(TRUE)
pins <- read.table(a[1], comment.char = "#", col.names = c("pkg", "ver"))
repo <- "https://packagemanager.posit.co/cran/__linux__/noble/2026-10-20"
miss <- setdiff(pins$pkg, rownames(installed.packages(a[2])))
if (length(miss)) install.packages(miss, lib = a[2], repos = repo)
bad <- 0
for (i in seq_len(nrow(pins))) {
  v <- as.character(packageVersion(pins$pkg[i], lib.loc = a[2]))
  if (v != pins$ver[i]) {
    cat("PIN MISMATCH", pins$pkg[i], v, "!=", pins$ver[i], "\n")
    bad <- 1
  }
}
if (bad) quit(status = 1)
cat("r-deps: all", nrow(pins), "pins match\n")
RS
Rscript "$tmp" "$here/r-pins.txt" "$lib"
rm -f "${tmp:?}"
