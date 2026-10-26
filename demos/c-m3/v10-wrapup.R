# C-M3 video 10 (native R): what the gate proved: both P3 examples hold their contract.
source("demos/native-lib.R")
src <- c(
  "ex <- c(\"c-m3-p3-tree\", \"c-m3-p3-kmeans\")",
  "out <- lapply(ex, function(e) capture.output(",
  "  source(file.path(\"r/agenticds/inst/examples\", e, \"run.R\"))))",
  "contracts <- sapply(out, function(o) grep(\"^contract:\", o, value = TRUE))",
  "length(contracts) == 2 && all(grepl(\"OK$\", contracts))")
ex <- c("c-m3-p3-tree", "c-m3-p3-kmeans")
Sys.setenv(ADS_ROOT = ".")
out <- lapply(ex, function(e) capture.output(source(file.path("r/agenticds/inst/examples", e, "run.R"))))
contracts <- sapply(out, function(o) grep("^contract:", o, value = TRUE))
nat_show("what the gate proved: both P3 examples hold their contract", src)
nat_row("example 1", contracts[1])
nat_row("example 2", contracts[2])
nat_verdict(src[5], length(contracts) == 2 && all(grepl("OK$", contracts)), "contract: c-m3 wrap-up OK")
