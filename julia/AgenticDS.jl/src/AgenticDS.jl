module AgenticDS

using CSV
using DataFrames
using JSON3
using OrderedCollections: OrderedDict
using MLJBase
using MLJLinearModels
using Statistics: mean, median, std
using Printf: Printf
using BenchmarkTools: BenchmarkTools

export read_penguins, na_policy, summarise_by_species, summary_json, NUMERIC_COLS
export read_folds, ols_closed_form, regression_metrics, fit_species, predict_species
export cv_rmse, p2_json
export read_split, read_centroids, confusion, accuracy, fit_species_clf, predict_species_clf
export kmeans_fixed, p3_json
export read_wine, validate_wine, split_wine, pipeline_wine, report_ttl
export aggregate_groupby, aggregate_loop, bench_wine

const NUMERIC_COLS = [:bill_length_mm, :bill_depth_mm, :flipper_length_mm, :body_mass_g]

"""
    read_penguins(path) -> DataFrame

Read the Palmer Penguins CSV with explicit column types ("NA" is missing).
"""
function read_penguins(path)
    types = Dict(
        :species => String,
        :island => String,
        :bill_length_mm => Union{Missing,Float64},
        :bill_depth_mm => Union{Missing,Float64},
        :flipper_length_mm => Union{Missing,Float64},
        :body_mass_g => Union{Missing,Float64},
        :sex => Union{Missing,String},
        :year => Int,
    )
    return CSV.read(path, DataFrame; missingstring = "NA", types = types)
end

"""
    na_policy(df) -> DataFrame

Drop rows with a missing value in any numeric measurement column. A missing `sex` alone keeps the row.
"""
function na_policy(df)
    clean = dropmissing(df, NUMERIC_COLS)
    return disallowmissing(clean, NUMERIC_COLS)
end

"""
    summarise_by_species(df) -> DataFrame

Count, mean and sample standard deviation (n-1) of each measurement, per species, sorted by species.
"""
function summarise_by_species(df)
    pairs = Pair[]
    for col in NUMERIC_COLS
        push!(pairs, col => mean => Symbol(col, "_mean"))
        push!(pairs, col => std => Symbol(col, "_sd"))
    end
    grouped = groupby(df, :species; sort = true)
    return combine(grouped, nrow => :n, pairs...)
end

"""
    summary_json(s) -> String

Serialise the per-species summary to the golden JSON layout (`datasets/golden/p1.json`).
"""
function summary_json(s)
    species = OrderedDict{String,Any}()
    for row in eachrow(s)
        entry = OrderedDict{String,Any}("n" => row.n)
        for col in NUMERIC_COLS
            entry[String(col)] = OrderedDict(
                "mean" => row[Symbol(col, "_mean")],
                "sd" => row[Symbol(col, "_sd")],
            )
        end
        species[row.species] = entry
    end
    return JSON3.write(OrderedDict("species" => species))
end

include("P2.jl")
include("P3.jl")
include("P4.jl")

end # module AgenticDS
