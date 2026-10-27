# C-M4 video 6: write the report, then break copies of it.
# Run from the repo root: source("<this file>")
f <- file.path("datasets", "wine-quality", "winequality-%s.csv")
w <- sprintf(f, c("red", "white"))
res <- agenticds::pipeline_wine(w[1], w[2])
ttl <- tempfile(fileext = ".ttl")
agenticds::report_ttl(res, ttl)
x <- readLines(ttl)
cat(x[4:8], sep = "\n")
shape <- readLines("ontology/shapes/artifact.shape.ttl")
need <- grep("sh:path", shape, value = TRUE)
need <- sub(".*sh:path (ads:\\w+).*", "\\1", need)
str <- any(grepl("schemaVersion.*xsd:string", shape))
conforms <- function(l) {
  v <- grep("^ *ads:schemaVersion", l, value = TRUE)
  all(need %in% sub("^ *(ads:\\w+).*", "\\1", l)) &&
    (!str || all(grepl("Version \"", v, fixed = TRUE)))
}
no_by <- x[!grepl("generatedBy", x)]
num <- sub("Version \"1\"", "Version 1", x, fixed = TRUE)
cases <- list(artifact = x, no_generatedBy = no_by, numeric = num)
print(vapply(cases, conforms, NA))
stopifnot(conforms(x), !conforms(no_by), !conforms(num))
agenticds::verdict(
  "contract: ads-r-p4 artifact ok, broken copies refused OK"
)
