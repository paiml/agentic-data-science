# Provable contract: ads-b-m2-v08-mutants. Two P2.jl mutants are caught by the tests.
root = abspath(joinpath(@__DIR__, "..", "..", ".."))
src = joinpath("julia", "AgenticDS.jl", "src", "P2.jl")
mutants = [
    "leaking fold" => ("df[folds .!= k, :]", "df"),
    "dropped intercept" => ("intercept = b[1],", "intercept = 0.0,"),
]
caught = Bool[]
for (name, (from, to)) in mutants
    sc = mktempdir()
    ls = read(Cmd(`git ls-files -z`; dir = root), String)
    files = split(ls, '\0'; keepempty = false)
    for f in files
        mkpath(dirname(joinpath(sc, f)))
        cp(joinpath(root, f), joinpath(sc, f); force = true)
    end
    p = joinpath(sc, src)
    write(p, replace(read(p, String), from => to))
    pkg = joinpath(sc, "julia", "AgenticDS.jl")
    tst = "using Pkg; Pkg.test()"
    cmd = Cmd(`$(Base.julia_cmd()) --project=$pkg -e $tst`; dir = sc)
    ok = success(pipeline(cmd; stdout = devnull, stderr = devnull))
    println("mutant ", name, ": ", ok ? "SURVIVED" : "caught by tests")
    push!(caught, !ok)
    rm(sc; recursive = true, force = true)
end
@assert all(caught)
println("contract: ads-b-m2-v08-mutants every mutant is caught OK")
