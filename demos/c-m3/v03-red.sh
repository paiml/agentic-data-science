#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M3 video 3: invert accuracy in a scratch copy; the p3 tests go red
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
# shellcheck source=../mutate.sh
source "$(dirname "$0")/../mutate.sh"
mutate p3.R 's/mean(truth == pred)/mean(truth != pred)/' p3
echo "contract: c-m3 inverted accuracy is caught OK"
