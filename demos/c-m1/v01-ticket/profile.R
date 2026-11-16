.First <- function() {
  options(cli.num_colors = 256L, width = 80, pillar.bold = TRUE, digits = 8)
  suppressMessages({library(prettycode); prettycode::prettycode()})
  cat(cli::col_grey(paste0("# ", R.version.string, " + prettycode")), "\n")
}
