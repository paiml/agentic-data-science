# repro: a sort-keyed split moves with the locale, row index does not
ids <- c("b1", "A2", "a3", "B4", "c5", "C6")
ord <- \(l) { Sys.setlocale("LC_COLLATE", l); order(ids) }
rbind(C = ord("C"), en_US = ord("en_US.UTF-8"))
f <- "datasets/wine-quality/winequality-%s.csv"
run <- \(l) { Sys.setlocale("LC_COLLATE", l)
  pipeline_wine(sprintf(f, "red"), sprintf(f, "white"))$rmse }
r <- c(C = run("C"), en_US = run("en_US.UTF-8"))
print(r, digits = 17)
ok <- !identical(ord("C"), ord("en_US.UTF-8")) && r[[1]] == r[[2]]
cat(cli::col_green(cli::style_bold(ok)), "\n")
