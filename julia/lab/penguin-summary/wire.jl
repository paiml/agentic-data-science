# Values-only wire format between the grader (no learner code) and the learner's child process.
# Only five column types cross; anything else is an error. No Serialization (it can construct arbitrary objects).
module Wire
using DataFrames, JSON3

const TAGS = Dict{Any,String}(
    String => "S", Union{Missing,String} => "S?", Float64 => "F", Union{Missing,Float64} => "F?",
    Int => "I", Missing => "M",
)

enc(x::AbstractFloat) = isfinite(x) ? x : string(x)   # "NaN", "Inf", "-Inf" (JSON has no such number)
enc(x) = ismissing(x) ? nothing : x

function encode(df::DataFrame)
    cols = Any[]
    for n in names(df)
        T = eltype(df[!, n])
        haskey(TAGS, T) || error("column $n has type $T, which does not cross the wire")
        push!(cols, Dict("name" => n, "tag" => TAGS[T], "vals" => Any[enc(x) for x in df[!, n]]))
    end
    return Dict("cols" => cols)
end

dec_f(v) = v isa AbstractString ? parse(Float64, v) : Float64(v)
const DEC = Dict(
    "S" => v -> String(v), "S?" => v -> v === nothing ? missing : String(v),
    "F" => dec_f, "F?" => v -> v === nothing ? missing : dec_f(v),
    "I" => v -> Int(v), "M" => v -> v === nothing ? missing : error("non-null in an M column"),
)
const VEC = Dict(
    "S" => String, "S?" => Union{Missing,String}, "F" => Float64, "F?" => Union{Missing,Float64},
    "I" => Int, "M" => Missing,
)

function decode(o)
    df = DataFrame()
    for c in o.cols
        tag = String(c.tag)
        haskey(DEC, tag) || error("unknown column tag $tag")
        df[!, Symbol(String(c.name))] = VEC[tag][DEC[tag](v) for v in c.vals]
    end
    return df
end

# A message is {"f": name, "arg": {"df": ..}|{"str": ..}}; a reply is {"df": ..}|{"str": ..}|{"err": ..}.
packarg(x::DataFrame) = Dict("df" => encode(x))
packarg(x::AbstractString) = Dict("str" => String(x))
unpack(o) = haskey(o, :df) ? decode(o.df) : haskey(o, :str) ? String(o.str) : error(haskey(o, :err) ? String(o.err) : "empty reply")
end
