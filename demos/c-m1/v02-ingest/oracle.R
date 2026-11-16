# typed ingest and the NA policy
raw <- readr::read_csv("datasets/penguins/penguins.csv", show_col_types = FALSE)
sapply(raw, class)
colSums(is.na(raw))
d <- raw[complete.cases(raw[3:6]), ]
c(raw = nrow(raw), clean = nrow(d), sex_na = sum(is.na(d$sex)))
# Provable contract: 344 rows, 342 after the NA policy, 9 missing sex. Fails the run otherwise.
stopifnot(nrow(raw) == 344, nrow(d) == 342, sum(is.na(d$sex)) == 9)
cat(cli::col_green(cli::style_bold("contract: 344 raw, 342 clean, 9 missing sex OK")), fill = TRUE)
