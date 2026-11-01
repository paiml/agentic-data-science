# Anscombe's quartet in R. Usage: Rscript run.R data/anscombe.csv OUT_DIR
# stdout is the numbers (stdout.txt); OUT_DIR/plot.svg is the figure.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
library(agenticds)
d <- anscombe_read(args[[1]])
s <- anscombe_summary(d)
cat(anscombe_lines(s), sep = "\n")
anscombe_svg(d, file.path(args[[2]], "plot.svg"))
stopifnot(all(abs(s$mean_x - 9) < 1e-9), all(abs(s$cor - 0.816) < 1e-3))
cat("contract: ads-demo-001 anscombe-r OK\n")
