# Native-R scene template (DEMO-NATIVE-001): loaded by the R console through R_PROFILE_USER, off-camera.
# Env (set per scene in the spec): ADS_RUN = pinned example run.R; the panel title is that path.
# It loads the pinned package, then prints the example's own source, highlighted, and holds it 4 s
# before the prompt returns, so the course code is on screen >= 3 s before anything is typed or run.
.First <- function() {
  options(cli.num_colors = 256L)
  suppressMessages(pkgload::load_all("r/agenticds", quiet = TRUE))
  run <- Sys.getenv("ADS_RUN")
  src <- readLines(run)
  src <- src[!grepl("^#", src)]
  cat("\033[2J\033[H")
  cat(cli::col_grey(paste0("# ", run)), "\n\n", sep = "")
  for (l in cli::code_highlight(src)) cat(l, "\n", sep = "")
  Sys.sleep(4)
  # The screen is cleared before the run, so the run prints the R version itself (the demo shows the tool version).
  assign("source", function(...) {
    cat(cli::col_grey(R.version.string), "\n", sep = "")
    base::source(...)
  }, envir = globalenv())
  cat("\n", cli::col_grey("# ready: R 4.6.1, agenticds loaded"), "\n", sep = "")
}
