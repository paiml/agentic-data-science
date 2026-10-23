#!/usr/bin/env bash
# B-M3 video 08-mutants: two mutants in a scratch copy, no centroid update and a split tie broken the wrong way; the tests catch both
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
# shellcheck source=../mutate.sh
source "$(dirname "$0")/../mutate.sh"
mutate P3.jl 's/any(members) && (cen\[k, :\] = vec(mean(z\[members, :\]; dims = 1)))/any(members)/'
mutate P3.jl 's/gain > best.gain/gain >= best.gain/'
echo "contract: b-m3 a k-means without its update and a split rule that prefers the later of two equal cuts are both caught OK"
