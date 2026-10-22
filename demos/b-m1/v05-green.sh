#!/usr/bin/env bash
# B-M1 video 5: the package tests, Aqua and JET included, pass
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
julia --project="$PKG" -e 'using Pkg; Pkg.test()' 2>&1 | grep -E '^(Test Summary:|AgenticDS P1|Aqua|JET) ' | sed -E 's/ +[0-9.]+m?[0-9.]*s$//; s/ +Time$//'
echo "contract: b-m1 tests, Aqua and JET green OK"
