module BM1

using AgenticDS
using CSV
using DataFrames
using JSON3
using SHA
using Statistics
using Test

include("helpers.jl")

module V01
using AgenticDS
using DataFrames
using ..BM1: DATA, gold_sp, sha_ok, verdict
include("v01_ticket.jl")
end

module V02
using AgenticDS
using DataFrames
using ..BM1: DATA, verdict
include("v02_ingest.jl")
end

module V03
using Pkg
using ..BM1: runtests, verdict
include("v03_generate.jl")
end

module V04
using AgenticDS
using DataFrames
using Statistics
using ..BM1: DATA, verdict
include("v04_profile.jl")
end

module V05
using ..BM1:
    ROOT, capture_cmd, julia_cmd, test_rows, verdict
include("v05_green.jl")
end

module V06
using AgenticDS
using DataFrames
using ..BM1: DATA, gold_sp, r2, verdict
include("v06_json.jl")
end

module V07
include("v07_gates.jl")
end

module V08
using AgenticDS
using ..BM1: failures, load_module, verdict
include("v08_mutants.jl")
end

module V09
using CSV
using DataFrames
using ..BM1: DATA, verdict
include("v09_parse.jl")
end

module V10
using ..BM1: ROOT, contracts, verdict
include("v10_wrapup.jl")
end

end
