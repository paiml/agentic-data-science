# c-m4 v06: report_ttl writes the Turtle artifact
h <- new.env()
sys.source("R/helpers.R", h)
library(agenticds)

run_scene <- function() {
  res <- pipeline_wine(h$wine("red"), h$wine("white"))
  out <- file.path(tempdir(), "wine-report-artifact.ttl")
  report_ttl(res, out)
  ttl <- readLines(out)
  writeLines(ttl)
  want <- readLines("data/p4-artifact.ttl")
  ok <- identical(ttl, want)
  h$verdict(ok, "artifact matches the golden ttl")
}

if (sys.nframe() == 0) run_scene()
