# typed ingest and the NA policy
raw <- readr::read_csv("datasets/penguins/penguins.csv", show_col_types = FALSE)
sapply(raw, class)
colSums(is.na(raw))
d <- raw[complete.cases(raw[3:6]), ]
c(raw = nrow(raw), clean = nrow(d), sex_na = sum(is.na(d$sex)))
ok <- nrow(raw) == 344 && nrow(d) == 342 && sum(is.na(d$sex)) == 9
cat(cli::col_green(cli::style_bold(ok)), fill = TRUE)
