module BM2

using CSV
using DataFrames
using JSON3
using Statistics

include("helpers.jl")

module V01
using ..BM2: golden, load, design, backslash
using ..BM2: near, round3, verdict
include("v01_ticket.jl")
end

module V02
using DataFrames: nrow
using ..BM2: load, verdict
include("v02_design.jl")
end

module V03
using ..BM2: backslash, red, verdict
include("v03_red_first.jl")
end

module V05
using Statistics: mean
using ..BM2: load, read_folds, golden, designs
using ..BM2: backslash, near, round3, verdict
using ..BM2: fold_sizes
include("v05_folds.jl")
end

module V06
using MLJBase: machine, fit!, fitted_params
using MLJLinearModels: LinearRegressor
using ..BM2: load, golden, species_table
using ..BM2: near, round3, verdict
using ..BM2: named_params, same_params
include("v06_mlj.jl")
end

module V07
include("v07_gate.jl")
end

module V08
using ..BM2: load, read_folds, golden, designs
using ..BM2: cv_oof, honest, backslash, near, verdict
include("v08_mutants.jl")
end

module V09
using ..BM2:
    load, read_folds, golden, designs, backslash
using ..BM2: cv_oof, near, trim4, contract, verdict
include("v09_examples.jl")
end

module V10
using ..BM2: verdict, V09
include("v10_wrapup.jl")
end

end
