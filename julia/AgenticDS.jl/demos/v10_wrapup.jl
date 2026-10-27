# Provable contract: ads-b-m2-v10-wrapup. Both P2 contracts print from the examples.
root = joinpath(@__DIR__, "..", "..", "..")
pkg = joinpath(root, "julia", "AgenticDS.jl")
jl = Base.julia_cmd()
lines = String[]
for e in ["b-m2-p2-ols", "b-m2-p2-cv"]
    run_e = joinpath(pkg, "examples", e, "run.jl")
    cmd = Cmd(`$jl --project=$pkg $run_e`; dir = root)
    out = read(pipeline(cmd; stderr = devnull), String)
    c = filter(startswith("contract:"), split(out, '\n'))
    println.(c)
    append!(lines, c)
end
@assert length(lines) == 2 && all(==("contract: ads-julia-p2-v1 OK"), lines)
println("contract: ads-b-m2-v10-wrapup both P2 contracts OK")
