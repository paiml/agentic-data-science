# Grader-owned stand-in for the learner's package, loaded in the GRADER's process. It holds no learner code: every
# call goes to the learner's child process over a socket (set up by run.jl) and returns VALUES only (wire.jl).
# A learner's __init__, exit(0) or printing runs in the child and cannot reach this process's variables or its verdict.
module AgenticDS
using DataFrames, JSON3
include("wire.jl")
export read_penguins, na_policy, summarise_by_species, summary_json, NUMERIC_COLS

const NUMERIC_COLS = [:bill_length_mm, :bill_depth_mm, :flipper_length_mm, :body_mass_g]
const RPC = Ref{Any}(nothing)   # run.jl sets this: (name::String, packed arg) -> JSON3 reply object

function call(name, arg)
    RPC[] === nothing && error("no learner child attached")
    return Wire.unpack(RPC[](name, arg))
end
read_penguins(path) = call("read_penguins", Wire.packarg(String(path)))
na_policy(df) = call("na_policy", Wire.packarg(df))
summarise_by_species(df) = call("summarise_by_species", Wire.packarg(df))
summary_json(s) = call("summary_json", Wire.packarg(s))
end
