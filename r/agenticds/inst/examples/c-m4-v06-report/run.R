# C-M4 video 6: write the report, then break a copy of it.
# Run from the repo root: source("<this file>")
library(agenticds)
f <- file.path("datasets", "wine-quality", "winequality-%s.csv")
res <- pipeline_wine(sprintf(f, "red"), sprintf(f, "white"))
ttl <- tempfile(fileext = ".ttl")
report_ttl(res, ttl)
x <- readLines(ttl)
cat(x[4:8], sep = "\n")
shape <- readLines("ontology/shapes/artifact.shape.ttl")
need <- grep("sh:path", shape, value = TRUE)
need <- sub(".*sh:path (ads:\\w+).*", "\\1", need)
conforms <- function(l) {
  all(need %in% sub("^ *(ads:\\w+).*", "\\1", l))
}
broken <- x[!grepl("generatedBy", x)]
cat("required:", need, "\n")
print(c(artifact = conforms(x), broken = conforms(broken)))
stopifnot(
  conforms(x), !conforms(broken), any(grepl("a ads:Artifact", x))
)
verdict("contract: ads-r-p4 artifact ok, broken copy refused OK")
