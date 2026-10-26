# C-M2 video 7 (native R): the R gate (covr 100, lintr 0, styler no diff) and SHACL, run locally.
source("demos/native-lib.R")
src <- c(
  "cov <- covr::percent_coverage(covr::package_coverage(\"r/agenticds\"))",
  "lints <- length(lintr::lint_package(\"r/agenticds\"))",
  "d <- styler::style_pkg(\"r/agenticds\", dry = \"on\")",
  "restyled <- sum(d$changed)",
  "shacl <- system2(\"make\", \"gate-shacl\", stdout = FALSE, stderr = FALSE)",
  "cov == 100 && lints == 0 && restyled == 0 && shacl == 0")
# The gate run takes ~40 s; setup runs it once and caches the figures, the scene shows them.
cache <- file.path(Sys.getenv("HOME"), "gates.rds")
if (!file.exists(cache)) {
  Sys.setenv(ADS_ROOT = normalizePath("."), R_LIBS = Sys.getenv("ADS_RLIB"))
  saveRDS(list(
    cov = covr::percent_coverage(covr::package_coverage("r/agenticds")),
    lints = length(lintr::lint_package("r/agenticds")),
    restyled = sum(styler::style_pkg("r/agenticds", dry = "on")$changed),
    shacl = system2("make", "gate-shacl", stdout = FALSE, stderr = FALSE)), cache)
}
g <- readRDS(cache)
cov <- g$cov; lints <- g$lints; restyled <- g$restyled; shacl <- g$shacl
nat_show("the gates, run locally: coverage, lint, style, SHACL", src)
nat_row("covr", sprintf("%g%% line coverage", cov))
nat_row("lintr", sprintf("%d lints", lints))
nat_row("styler", sprintf("%d files would change", restyled))
nat_row("shacl", if (shacl == 0) "conforms" else "FAILED")
nat_verdict(src[6], cov == 100 && lints == 0 && restyled == 0 && shacl == 0, "contract: c-m2 gates green OK")
