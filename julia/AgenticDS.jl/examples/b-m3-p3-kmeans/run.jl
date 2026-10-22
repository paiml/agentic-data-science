# P3 (b): k-means from the fixed centroids, checked against the golden.
# Usage: julia --project=julia/AgenticDS.jl julia/AgenticDS.jl/examples/b-m3-p3-kmeans/run.jl
# Provable contract: ads-julia-p3-v1, objective within 1e-6 of datasets/golden/p3.json.
using AgenticDS
using JSON3
d = na_policy(read_penguins(joinpath("datasets", "penguins", "penguins.csv")))
centroids = read_centroids(joinpath("datasets", "fixtures", "centroids.csv"))
km = kmeans_fixed(d, centroids)
sizes = [count(==(k), km.cluster) for k = 1:3]
println("objective: ", km.objective)
println("cluster sizes: ", sizes)
golden = JSON3.read(read(joinpath("datasets", "golden", "p3.json"), String))
@assert isapprox(km.objective, golden.kmeans.objective; atol = 1e-6)
@assert sizes == golden.kmeans.cluster_sizes
println("contract: ads-julia-p3-v1 OK")
