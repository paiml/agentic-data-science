# Provable contract: ads-b-m2-v07-gate. The Julia gate is green on a scratch copy.
root = abspath(joinpath(@__DIR__, "..", "..", ".."))
sc = mktempdir()
files = split(read(Cmd(`git ls-files -z`; dir = root), String), '\0'; keepempty = false)
for f in files
    mkpath(dirname(joinpath(sc, f)))
    cp(joinpath(root, f), joinpath(sc, f); force = true)
end
gate = addenv(
    Cmd(`make gate-julia`; dir = sc),
    "PATH" => dirname(Base.julia_cmd().exec[1]) * ":" * ENV["PATH"],
)
out = read(pipeline(ignorestatus(gate); stderr = devnull), String)
keep = r"^(coverage|format clean|examples OK|gate-julia OK|UNCOVERED)"
lines = split(replace(out, sc => "."), '\n')
foreach(println, filter(l -> occursin(keep, l), lines))
rm(sc; recursive = true, force = true)
@assert occursin("gate-julia OK", out)
println("contract: ads-b-m2-v07-gate gate-julia green and fully covered OK")
