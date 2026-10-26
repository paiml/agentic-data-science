.First <- function() {
  options(cli.num_colors = 256L, width = 80, pillar.bold = TRUE, digits = 8)
  suppressMessages({library(parsnip); library(prettycode); prettycode::prettycode()})
  assign("d", stats::na.omit(readr::read_csv("datasets/penguins/penguins.csv", show_col_types = FALSE)), envir = globalenv())
  cat(cli::col_grey(paste0("# ", R.version.string, " + prettycode")), "\n")
}
