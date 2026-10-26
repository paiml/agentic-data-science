module PenguinsOLS

using CSV
using CairoMakie
using DataFrames
using GLM

include("plot.jl")
include("fit.jl")

export load_penguins, fit_ols, save_plot, main

end
