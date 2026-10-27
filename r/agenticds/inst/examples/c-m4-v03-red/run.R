# C-M4 video 3: shift the test rows in a copy; checks go red.
library(agenticds)
f <- "datasets/wine-quality/winequality-%s.csv"
w <- read_wine(sprintf(f, "red"), sprintf(f, "white"))
g <- jsonlite::fromJSON("datasets/golden/p4.json")
src <- sub("== 0L", "== 1L", deparse(split_wine), fixed = TRUE)
shifted <- eval(parse(text = src))
cat("mutation: test rows are row mod 5 is 1, not 0\n")
checks <- function(split) {
  s <- split(w)
  fit <- lm(quality ~ ., data = s$train)
  p <- predict(fit, s$test)
  rmse <- regression_metrics(s$test$quality, p)$rmse
  c(
    rule = identical(s$test, w[seq(5, nrow(w), 5), ]),
    count = nrow(s$test) == g$n_test,
    rmse = isTRUE(all.equal(rmse, g$rmse, tolerance = 1e-9))
  )
}
res <- rbind(ours = checks(split_wine), shifted = checks(shifted))
print(res)
stopifnot(all(res["ours", ]), !any(res["shifted", ]))
verdict("contract: ads-r-p4 a shifted split is caught OK")
