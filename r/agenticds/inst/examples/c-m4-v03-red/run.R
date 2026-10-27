# C-M4 video 3: shift the test rows in a copy; checks go red.
# Usage (from the repo root): source("<this file>")
f <- "datasets/wine-quality/winequality-%s.csv"
w <- agenticds::read_wine(sprintf(f, "red"), sprintf(f, "white"))
g <- jsonlite::fromJSON("datasets/golden/p4.json")
ours <- agenticds::split_wine
src <- sub("== 0L", "== 1L", deparse(ours), fixed = TRUE)
shifted <- eval(parse(text = src))
cat("mutation: test rows are row mod 5 is 1, not 0\n")
checks <- function(split) {
  s <- split(w)
  p <- predict(lm(quality ~ ., s$train), s$test)
  m <- agenticds::regression_metrics(s$test$quality, p)
  c(
    rule = identical(s$test, w[seq(5, nrow(w), 5), ]),
    count = nrow(s$test) == g$n_test,
    rmse = isTRUE(all.equal(m$rmse, g$rmse, tolerance = 1e-9))
  )
}
res <- rbind(ours = checks(ours), shifted = checks(shifted))
print(res)
stopifnot(all(res["ours", ]), !any(res["shifted", ]))
agenticds::verdict(
  "contract: ads-r-p4 a shifted split is caught OK"
)
