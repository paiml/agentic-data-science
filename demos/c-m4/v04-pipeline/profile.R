.First <- function() {
  options(cli.num_colors = 256L, width = 80, pillar.bold = TRUE, digits = 8)
  suppressMessages({
    pkgload::load_all("r/agenticds", quiet = TRUE)
    library(prettycode); prettycode::prettycode()
  })
  f <- "datasets/wine-quality/winequality-%s.csv"
  assign("w", read_wine(sprintf(f, "red"), sprintf(f, "white")), envir = globalenv())
  cat(cli::col_grey(paste0("# ", R.version.string, " + prettycode")), "\n")
}
