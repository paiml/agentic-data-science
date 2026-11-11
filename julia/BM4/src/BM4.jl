module BM4

using BenchmarkTools
using CSV
using DataFrames
using JSON3
using LinearAlgebra
using Printf
using SHA
using Statistics

include("helpers.jl")

# One module per example; the file in src/ is the example.
module V01
using CSV, DataFrames, SHA
using ..BM4:
    CONTRACT, DATA, RED, SUMS, WHITE, golden, verdict
include("v01_ticket.jl")
end

module V02
using CSV, DataFrames
using ..BM4: RED, WHITE, check, refuse_all, verdict
include("v02_ingest.jl")
end

module V03
using DataFrames
using ..BM4: RED, WHITE, by_mask, verdict
using ..V02: read_wine
include("v03_split.jl")
end

module V04
using DataFrames, Statistics
using ..BM4: RED, WHITE, compare, golden, lstsq, verdict
using ..V02: read_wine, validate_wine
using ..V03: split_wine
include("v04_pipeline.jl")
end

module V06
using Printf
using ..BM4: R_TTL, RED, TTL_HEAD, WHITE, verdict
using ..V04: pipeline_wine
include("v06_report.jl")
end

module V05
using DataFrames, Statistics
using ..BM4:
    R_TTL,
    RED,
    WHITE,
    failed,
    golden,
    lstsq,
    near,
    verdict
using ..V02: read_wine, validate_wine
using ..V03: split_wine
using ..V06: report_ttl, same_ttl
const V04_FILE = joinpath(@__DIR__, "v04_pipeline.jl")

# Evaluate the mutated pipeline source in a fresh module.
function sandbox(src)
    m = Module(:Mutant)
    for (k, v) in (
        :read_wine => read_wine,
        :validate_wine => validate_wine,
        :split_wine => split_wine,
        :lstsq => lstsq,
        :nrow => nrow,
        :mean => mean,
    )
        Core.eval(m, :(const $k = $v))
    end
    Base.include_string(m, src)
    return m
end

# The leaky pipeline's result on the real data.
function run_mutant(src)
    m = sandbox(src)
    return Core.eval(m, :(pipeline_wine($RED, $WHITE)))
end
include("v05_leak.jl")
end

module V07
using SHA
using ..BM4: R_TTL, ROOT, SHAPES, verdict
include("v07_gates.jl")
end

module V08
using BenchmarkTools, DataFrames, Statistics
using ..BM4: RED, WHITE, agree, golden, table, verdict
using ..V02: read_wine
include("v08_bench.jl")
end

module V09
using ..BM4: RED, WHITE, captured, golden, near, verdict
using ..V02: read_wine
using ..V04: pipeline_wine
using ..V06: report_ttl
using ..V08: bench_wine
include("v09_examples.jl")
end

module V10
using ..BM4:
    BAD,
    claim,
    RED,
    WHITE,
    golden,
    near,
    refusal,
    verdict,
    with
using ..V02: read_wine, validate_wine
using ..V04: pipeline_wine
include("v10_wrapup.jl")
end

end
