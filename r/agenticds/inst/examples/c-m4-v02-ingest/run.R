# C-M4 video 2: read both colours, reject bad rows. Run: source(...)
library(agenticds)
f <- "datasets/wine-quality/winequality-%s.csv"
w <- read_wine(sprintf(f, "red"), sprintf(f, "white"))
print(table(w$color))
cat(
  "columns:", ncol(w), " int quality:",
  is.integer(w$quality), "\n"
)
bad <- list(missing = w, quality = w, color = w)
bad$missing$alcohol[1] <- NA
bad$quality$quality[1] <- 11L
bad$color$color[1] <- "rose"
msg <- lapply(bad, function(x) {
  tryCatch(validate_wine(x), error = conditionMessage)
})
for (n in names(msg)) cat("rejected", n, ":", msg[[n]], "\n")
stopifnot(
  identical(validate_wine(w), w), nrow(w) == 6497L, ncol(w) == 13L,
  grepl("missing", msg$missing), grepl("quality", msg$quality),
  grepl("unknown color", msg$color)
)
verdict("contract: ads-r-p4 6497 rows, three defects rejected OK")
