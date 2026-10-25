#!/usr/bin/env bash
# A-M1 video 4: the committed golden file
# shellcheck source=../lib-rust.sh
source "$(dirname "$0")/../lib-rust.sh"
head -28 <(jq . datasets/golden/p1.json)
echo "contract: a-m1 v04 golden-json OK"
