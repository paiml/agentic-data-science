#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M3 video 6: mutation testing, two mutants, both killed
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
# shellcheck source=../mutate.sh
source "$(dirname "$0")/../mutate.sh"
killed=0
mutate p3.R 's/scale = spread)$/scale = spread * 2)/' p3 && killed=$((killed + 1))
mutate p3.R 's/(z - rep(cen\[k, \], each = nrow(z)))^2/abs(z - rep(cen[k, ], each = nrow(z)))/' p3 && killed=$((killed + 1))
echo "mutants killed: $killed of 2"
[ "$killed" -eq 2 ]
echo "contract: c-m3 2 of 2 mutants killed OK"
