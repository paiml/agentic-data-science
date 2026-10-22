#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M4 video 2: read_wine binds both colours; validate_wine rejects each defect
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'library(agenticds)
df <- read_wine("datasets/wine-quality/winequality-red.csv", "datasets/wine-quality/winequality-white.csv")
print(table(df$color)); cat("columns:", ncol(df), " quality integer:", is.integer(df$quality), "\n")
stopifnot(identical(validate_wine(df), df))
na <- df; na$alcohol[1] <- NA
bq <- df; bq$quality[1] <- 11L
bc <- df; bc$color[1] <- "rose"
for (x in list(na, bq, bc)) cat("rejected:", tryCatch({ validate_wine(x); "NOT REJECTED" }, error = function(e) conditionMessage(e)), "\n")
stopifnot(nrow(df) == 6497L, all(vapply(list(na, bq, bc), function(x) inherits(try(validate_wine(x), silent = TRUE), "try-error"), logical(1))))
cat("contract: c-m4 6497 rows, three defect classes rejected OK\n")'
