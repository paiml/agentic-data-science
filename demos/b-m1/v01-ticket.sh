#!/usr/bin/env bash
# B-M1 video 01-ticket: the ticket's oracle, checksums then golden vs the raw data
# shellcheck source=../lib-julia.sh
source "$(dirname "$0")/../lib-julia.sh"
(cd datasets/penguins && sha256sum -c SHA256SUMS)
julia --project="$PKG" -e '
using AgenticDS, DataFrames, JSON3
g = JSON3.read(read("datasets/golden/p1.json", String))
raw = read_penguins("datasets/penguins/penguins.csv"); d = na_policy(raw)
println("raw rows ", nrow(raw), ", rows dropped ", nrow(raw) - nrow(d), ", clean rows ", nrow(d))
ns = [g.species[Symbol(s)].n for s in ["Adelie", "Chinstrap", "Gentoo"]]
println("golden n: ", ns, " sums to ", sum(ns))
@assert ns == [count(==(s), d.species) for s in ["Adelie", "Chinstrap", "Gentoo"]]
@assert sum(ns) == nrow(d) == 342 && nrow(raw) == 344
println("contract: b-m1 ticket oracle is consistent with the data (344 -> 342) OK")'
