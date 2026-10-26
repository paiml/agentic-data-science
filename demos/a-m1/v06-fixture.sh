#!/usr/bin/env bash
# A-M1 video 6: the fixture the run reads
# shellcheck source=../lib-rust.sh
source "$(dirname "$0")/../lib-rust.sh"
head -4 datasets/penguins/penguins.csv
echo "contract: a-m1 v06 fixture OK"
