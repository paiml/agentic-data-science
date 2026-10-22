const P3 = JSON3.read(read(joinpath(ROOT, "datasets", "golden", "p3.json"), String))
const SPLIT_PATH = joinpath(ROOT, "datasets", "fixtures", "split.csv")
const CENTROIDS_PATH = joinpath(ROOT, "datasets", "fixtures", "centroids.csv")

@testset "AgenticDS P3" begin
    d = na_policy(read_penguins(CSV_PATH))
    split = read_split(SPLIT_PATH)
    centroids = read_centroids(CENTROIDS_PATH)

    @testset "fixtures" begin
        @test length(split) == 342
        @test count(==("train"), split) == 257
        @test count(==("test"), split) == 85
        @test size(centroids) == (3, 4)
        @test centroids[1, :] == [39.1, 18.7, 181.0, 3750.0]
    end

    @testset "confusion and accuracy" begin
        truth = ["a", "a", "b", "b", "b"]
        pred = ["a", "b", "b", "b", "a"]
        @test confusion(truth, pred, ["a", "b"]) == [1 1; 1 2]
        @test sum(confusion(truth, pred, ["a", "b"])) == length(truth)
        @test accuracy(truth, pred) == 3 / 5
    end

    @testset "decision tree" begin
        fit = fit_species_clf(d[split .== "train", :])
        @test fit.classes == ["Adelie", "Chinstrap", "Gentoo"]
        # rpart's tree: flipper < 207.5, then bill_length < 43.35 on the left; nothing else survives cp
        @test fit.tree.var == 3 && fit.tree.cut == 207.5
        @test fit.tree.left.var == 1 && fit.tree.left.cut == 43.35
        @test fit.tree.left.left.label == 1 && fit.tree.left.right.label == 2
        @test fit.tree.right.label == 3
        test = d[split .== "test", :]
        pred = predict_species_clf(fit, test)
        @test isapprox(accuracy(test.species, pred), P3.accuracy; atol = 1e-12)
        @test confusion(test.species, pred, fit.classes) == reduce(hcat, P3.confusion)'
        @test fit.classes == P3.classes
    end

    @testset "stopping rules" begin
        # a pure node and a node below minsplit both become leaves
        pure = DataFrame(;
            species = fill("Adelie", 30),
            bill_length_mm = collect(1.0:30),
            bill_depth_mm = collect(1.0:30),
            flipper_length_mm = collect(1.0:30),
            body_mass_g = collect(1.0:30),
        )
        @test fit_species_clf(pure).tree == AgenticDS.Leaf(1)
        few = first(d, 19)
        @test fit_species_clf(few).tree isa AgenticDS.Leaf
    end

    @testset "k-means" begin
        km = kmeans_fixed(d, centroids)
        @test isapprox(km.objective, P3.kmeans.objective; atol = 1e-6)
        @test [count(==(k), km.cluster) for k = 1:3] == P3.kmeans.cluster_sizes
        # one iteration is not converged, so its objective is no lower than the converged one
        one = kmeans_fixed(d, centroids; max_iter = 1)
        @test one.objective >= km.objective
        # an unreachable centroid keeps its place and its cluster stays empty
        far = copy(centroids)
        far[3, :] .= 1e9
        gone = kmeans_fixed(d, far)
        @test count(==(3), gone.cluster) == 0
    end

    @testset "p3_json" begin
        out = p3_json(d, split, centroids)
        @test isapprox(out["accuracy"], P3.accuracy; atol = 1e-12)
        @test out["confusion"] == [collect(r) for r in P3.confusion]
        @test out["classes"] == P3.classes
        @test isapprox(out["kmeans"]["objective"], P3.kmeans.objective; atol = 1e-6)
        @test out["kmeans"]["cluster_sizes"] == P3.kmeans.cluster_sizes
    end
end
