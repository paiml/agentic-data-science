# report: write the Turtle artifact, then break a copy of it
f <- "datasets/wine-quality/winequality-%s.csv"
res <- pipeline_wine(sprintf(f, "red"), sprintf(f, "white"))
ttl <- tempfile(fileext = ".ttl"); report_ttl(res, ttl)
x <- readLines(ttl); cat(x[4:8], sep = "\n")
broken <- x[!grepl("generatedBy", x)]
has <- \(l) any(grepl("ads:generatedBy", l))
c(artifact = has(x), broken = has(broken))
ok <- has(x) && !has(broken) && any(grepl("a ads:Artifact", x))
cat(cli::col_green(cli::style_bold(ok)), "\n")
