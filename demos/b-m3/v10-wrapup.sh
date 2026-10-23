#!/usr/bin/env bash
# B-M3 video 10-wrapup: wrap-up, both P3 contracts and the golden numbers
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
for e in b-m3-p3-tree b-m3-p3-kmeans; do julia --project="$PKG" "julia/AgenticDS.jl/examples/$e/run.jl" | grep '^contract:'; done
echo "accuracy 0.976470588235294, confusion [[37,0,0],[0,16,1],[0,1,30]], k-means 378.2936 / 133,123,86"
echo "contract: b-m3 wrap-up OK"
