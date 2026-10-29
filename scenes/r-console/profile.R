# Native-R scene template: loaded by the R console through R_PROFILE_USER, off-camera.
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
  # Cosmetics: package messages (the styler cache notice) are silenced, an empty covr zero_coverage table prints
  # one honest line instead of "<0 rows>", and a "# done" line follows the run so the capture waits for the prompt.
  # covr returns a plain data.frame, so zero_coverage() is tagged with a class the print method below can see.
  if (requireNamespace("covr", quietly = TRUE)) {
    ns <- asNamespace("covr")
    zc <- get("zero_coverage", envir = ns)
    unlockBinding("zero_coverage", ns)
    assign("zero_coverage", function(...) {
      x <- zc(...)
      class(x) <- c("zero_coverage", class(x))
      x
    }, envir = ns)
    lockBinding("zero_coverage", ns)
    registerS3method("print", "zero_coverage", function(x, ...) {
      if (nrow(x) == 0L) cat("covr: no uncovered lines\n") else NextMethod()
      invisible(x)
    })
  }
  assign("source", function(...) {
    cat(cli::col_grey(R.version.string), "\n", sep = "")
    suppressMessages(base::source(...))
    Sys.sleep(2.5)
    cat(cli::col_grey("# done"), "\n", sep = "")
    invisible(NULL)
  }, envir = globalenv())
  cat(cli::col_grey("# ready: ", R.version.string, ", agenticds loaded"), "\n", sep = "")
}
