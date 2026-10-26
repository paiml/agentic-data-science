#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M2 video 1: the ticket's oracle is the golden file
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'g <- jsonlite::fromJSON("datasets/golden/p2.json"); print(g$ols); print(g$metrics)
stopifnot(all(c("ols","species_model","metrics","cv_rmse") %in% names(g)))
cat("contract: c-m2 ticket oracle present OK\n")'
