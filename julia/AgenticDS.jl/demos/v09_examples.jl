# Provable contract: ads-b-m2-v09-examples. Both P2 examples end on their contract line.
root = joinpath(@__DIR__, "..", "..", "..")
pkg = joinpath(root, "julia", "AgenticDS.jl")
jl = Base.julia_cmd()
ok = Bool[]
for e in ["b-m2-p2-ols", "b-m2-p2-cv"]
    println("--- examples/", e)
    run_e = joinpath(pkg, "examples", e, "run.jl")
    cmd = Cmd(`$jl --project=$pkg $run_e`; dir = root)
    out = read(pipeline(cmd; stderr = devnull), String)
    print(replace(out, r"([0-9]+\.[0-9]{4})[0-9]+" => s"\1"))
    push!(ok, endswith(strip(out), "contract: ads-julia-p2-v1 OK"))
end
@assert all(ok)
println("contract: ads-b-m2-v09-examples both P2 examples end on ads-julia-p2-v1 OK")
