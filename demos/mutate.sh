#!/usr/bin/env bash
# Scratch-copy mutation helper for demos: mutate <R file under R/> <sed expr> <testthat filter>
# Prints the names of failing tests; returns 0 when the mutant is killed (>=1 failure, 0 errors).
mutate() {
  local file="$1" expr="$2" filt="$3" sc
  sc="$(mktemp -d)"
  cp -r "$ADS_ROOT/r/agenticds" "$sc/pkg"
  cp -r "$ADS_ROOT/datasets" "$sc/datasets"
  sed -i "$expr" "$sc/pkg/R/$file"
  echo "mutation in R/$file: sed '$expr'"
  diff <(cat "$ADS_ROOT/r/agenticds/R/$file") "$sc/pkg/R/$file" | grep '^[<>]' || true
  FILT="$filt" SCRATCH="$sc" ADS_ROOT="$sc" Rscript -e '
    r <- as.data.frame(testthat::test_dir(file.path(Sys.getenv("SCRATCH"), "pkg", "tests", "testthat"),
      filter = Sys.getenv("FILT"), package = "agenticds", load_package = "source",
      reporter = "silent", stop_on_failure = FALSE))
    cat("passed:", sum(r$passed), " failed:", sum(r$failed), " errored:", sum(r$error), "\n")
    print(r[r$failed > 0 | r$error, "test"])
    quit(status = if (sum(r$failed) > 0 && sum(r$error) == 0) 0 else 1)' || { rm -rf -- "${sc:?}"; return 1; }
  rm -rf -- "${sc:?}"
}
