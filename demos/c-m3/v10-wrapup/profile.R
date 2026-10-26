.First <- function() {
  options(cli.num_colors = 256L, width = 80, digits = 8,
          readr.show_progress = FALSE)
  suppressMessages({
    library(parsnip); library(prettycode); prettycode::prettycode()
    pkgload::load_all("r/agenticds", quiet = TRUE)})
  Sys.setenv(ADS_ROOT = getwd())
  evalq({
    d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
    s <- read_split("datasets/fixtures/split.csv")
    cen <- read_centroids("datasets/fixtures/centroids.csv")
    g <- jsonlite::fromJSON("datasets/golden/p3.json")
  }, globalenv())
  cat(cli::col_grey(paste0("# ", R.version.string, " + prettycode")), "\n")
}
