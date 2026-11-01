# Anscombe's quartet in R. Usage: Rscript run.R DATA_DIR OUT_DIR
# Writes OUT_DIR/stdout.txt (the numbers, same bytes as every language)
# and OUT_DIR/plot.svg; the contract line goes to the console only.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
library(agenticds)
d <- anscombe_read(file.path(args[[1]], "anscombe.csv"))
s <- anscombe_summary(d)
lines <- anscombe_lines(s)
writeLines(lines, file.path(args[[2]], "stdout.txt"))
anscombe_svg(d, file.path(args[[2]], "plot.svg"))
cat(lines, sep = "\n")
stopifnot(
  all(abs(s$mean_x - 9) < 1e-9),
  all(abs(s$cor - 0.816) < 1e-3),
  length(unique(sub("^set [IV]+: n=11 ", "", lines))) == 1L
)
cat("contract: ads-demo-001 anscombe-r OK\n")
