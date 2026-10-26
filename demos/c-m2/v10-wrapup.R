# C-M2 video 10 (native R): what the gate proved: both P2 examples hold their contract.
source("demos/native-lib.R")
src <- c(
  "ex <- c(\"c-m2-p2-ols\", \"c-m2-p2-cv\")",
  "out <- lapply(ex, function(e) capture.output(",
  "  source(file.path(\"r/agenticds/inst/examples\", e, \"run.R\"))))",
  "contracts <- sapply(out, function(o) grep(\"^contract:\", o, value = TRUE))",
  "length(contracts) == 2 && all(grepl(\"OK$\", contracts))")
ex <- c("c-m2-p2-ols", "c-m2-p2-cv")
Sys.setenv(ADS_ROOT = ".")
out <- lapply(ex, function(e) capture.output(source(file.path("r/agenticds/inst/examples", e, "run.R"))))
contracts <- sapply(out, function(o) grep("^contract:", o, value = TRUE))
nat_show("what the gate proved: both P2 examples hold their contract", src)
nat_row("example 1", contracts[1])
nat_row("example 2", contracts[2])
nat_verdict(src[5], length(contracts) == 2 && all(grepl("OK$", contracts)), "contract: c-m2 wrap-up OK")
