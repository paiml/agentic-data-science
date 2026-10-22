# P1 (b): per-species profile (n, mean, sample SD) written as the golden JSON layout.
# Usage: julia --project=julia/AgenticDS.jl julia/AgenticDS.jl/examples/b-m1-p1-profile/run.jl [path/to/penguins.csv]
using AgenticDS
using JSON3
path = isempty(ARGS) ? joinpath("datasets", "penguins", "penguins.csv") : ARGS[1]
profile = summarise_by_species(na_policy(read_penguins(path)))
show(stdout, MIME("text/plain"), profile)
println()
golden = JSON3.read(read(joinpath("datasets", "golden", "p1.json"), String))
for row in eachrow(profile)
    g = golden.species[Symbol(row.species)]
    @assert row.n == g.n
    @assert isapprox(row.body_mass_g_mean, g.body_mass_g.mean; atol = 1e-9)
    @assert isapprox(row.body_mass_g_sd, g.body_mass_g.sd; atol = 1e-9)
end
println("contract: ads-julia-p1-v1 OK")
