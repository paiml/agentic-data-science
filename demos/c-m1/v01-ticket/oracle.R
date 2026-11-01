# the ticket's oracle: does the golden file agree with the data?
sums <- readLines("datasets/penguins/SHA256SUMS")
want <- strsplit(sums[1], " +")[[1]][1]
out <- system("sha256sum datasets/penguins/penguins.csv", intern = TRUE)
got <- strsplit(out, " +")[[1]][1]
sha_ok <- identical(got, want)
raw <- read.csv("datasets/penguins/penguins.csv")
d <- raw[complete.cases(raw[3:6]), ]
c(raw = nrow(raw), clean = nrow(d))
g <- jsonlite::fromJSON("datasets/golden/p1.json")
ns <- sapply(g$species, function(s) s$n)
ok <- all(ns == table(d$species)[names(ns)]) && sum(ns) == nrow(d)
# Provable contract: the committed CSV matches its checksum and the golden species counts. Fails the run otherwise.
stopifnot(sha_ok, ok)
cat(cli::col_green(cli::style_bold("contract: penguins.csv checksum and golden species counts agree OK")), fill = TRUE)
