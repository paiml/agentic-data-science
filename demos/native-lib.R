# Shared helpers for native-R demo scenes (DEMO-NATIVE-001): source pane, run, verdict.
# Layout (0-based screen rows): 0 title, 2.. source lines, then blank, "# run", output rows, echo, verdict.
.libPaths(c(Sys.getenv("ADS_RLIB"), .libPaths()))
options(cli.num_colors = 256L)
suppressMessages(pkgload::load_all("r/agenticds", quiet = TRUE))
nat_show <- function(title, src) {
  cat("\033[2J\033[H")
  cat(cli::col_grey(paste0("# ", title)), "\n\n", sep = "")
  for (l in cli::code_highlight(src)) cat(cli::col_grey("> "), l, "\n", sep = "")
  Sys.sleep(4)
  cat("\n", cli::col_grey("# run"), "\n", sep = "")
}
nat_row <- function(label, text) {
  cat(cli::col_cyan(sprintf("%-16s", label)), text, "\n", sep = "")
}
nat_verdict <- function(check_src, ok, contract) {
  stopifnot(isTRUE(ok))
  Sys.sleep(1.5)
  cat(cli::col_grey("> "), cli::code_highlight(check_src)[1], "\n", sep = "")
  cat(cli::style_bold(cli::col_green("[1] TRUE")), "\n", sep = "")
  Sys.sleep(3)
  cat(contract, "\n", sep = "")
  Sys.sleep(3.5)
}
# nat_killed: does the p-filter test suite kill this sed mutant of R/<file>? (scratch copy via demos/mutate.sh)
nat_killed <- function(expr, file, filt) {
  Sys.setenv(ADS_ROOT = normalizePath("."), R_LIBS = Sys.getenv("ADS_RLIB"))
  cmd <- paste("source demos/mutate.sh; mutate", shQuote(file), shQuote(expr), shQuote(filt))
  system2("bash", c("-c", shQuote(cmd)), stdout = FALSE, stderr = FALSE) == 0
}
