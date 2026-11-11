module BM3

using CSV
using DataFrames
using SHA
using Statistics

include("helpers.jl")

module V01
using ..BM3: GOLD, checksum_ok, rnd, task, verdict
include("v01_ticket.jl")
end

module V02
using ..BM3: COLS, task, table_row, verdict, rnd
using ..BM3: standard
using Statistics
include("v02_features.jl")
end

module V03
using ..BM3: verdict, sizes
include("v03_split.jl")
end

include("tree.jl")

module V04
using ..BM3: Leaf, Split, MINSPLIT, MINBUCKET, CP, GOLD
using ..BM3: best_split, fit_tree, score, outline
using ..BM3: show_tree, verdict, settings, SHAPE
include("v04_tree.jl")
end

module V05
using ..BM3: GOLD, task, fit_tree, predict
using ..BM3: wide_row, rnd, verdict
include("v05_confusion.jl")
end

module V06
using ..BM3: GOLD, scaled, sq, rnd, verdict
using ..BM3: scores, sizes, kmeans_golden
using Statistics
include("v06_kmeans.jl")
end

module V07
using ..BM3: verdict
include("v07_gates.jl")
end

module V08
using ..BM3: GOLD, ROOT, scaled, verdict, hit_line
include("v08_mutants.jl")
end

module V09
using ..BM3: GOLD, task, fit_tree, predict, scaled
using ..BM3: verdict, V05, V06
include("v09_examples.jl")
end

module V10
using ..BM3: GOLD, task, scaled, rnd, verdict
using ..BM3: V06, V09, contract
include("v10_wrapup.jl")
end

end
