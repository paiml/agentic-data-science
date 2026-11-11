module AgenticDS

using CSV
using DataFrames
using JSON3
using OrderedCollections: OrderedDict
using Statistics: mean, std

export read_penguins, na_policy, summarise_by_species, summary_json, NUMERIC_COLS

const NUMERIC_COLS = [:bill_length_mm, :bill_depth_mm, :flipper_length_mm, :body_mass_g]

"""
    read_penguins(path) -> DataFrame

Read the Palmer Penguins CSV with explicit column types ("NA" is missing).
Given: you do not edit this one.
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

TODO 1. Drop every row that has a missing value in ANY of `NUMERIC_COLS`.
A missing `sex` alone must keep the row. The returned numeric columns must be
plain `Float64` (no `Missing` in the element type).
"""
function na_policy(df)
    error("TODO 1: implement na_policy")
end

"""
    summarise_by_species(df) -> DataFrame

TODO 2. One row per species, sorted by species, with columns `n`, and for each
measurement `<col>_mean` and `<col>_sd`. The sd is the SAMPLE standard
deviation (divide by n - 1).
"""
function summarise_by_species(df)
    error("TODO 2: implement summarise_by_species")
end

"""
    summary_json(s) -> String

TODO 3. Serialise the summary to JSON shaped
`{"species":{"Adelie":{"n":3,"bill_length_mm":{"mean":..,"sd":..},...},...}}`
with species in the order of `s` and measurements in the order of `NUMERIC_COLS`.
"""
function summary_json(s)
    error("TODO 3: implement summary_json")
end

end # module AgenticDS
