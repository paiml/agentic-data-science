# wrap-up: both P4 contracts, run and read back
ex <- c("c-m4-p4-pipeline", "c-m4-p4-bench")
out <- lapply(ex, \(e) capture.output(source(
  file.path("r/agenticds/inst/examples", e, "run.R"), local = TRUE)))
lines <- grep("^contract:", unlist(out), value = TRUE)
writeLines(lines)
ok <- length(lines) == 2L && all(endsWith(lines, "OK"))
cat(cli::col_green(cli::style_bold(ok)), "\n")
