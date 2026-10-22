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
        truth = ["a", "a", "b"]
        pred = ["a", "b", "b"]
        @test confusion(truth, pred, ["a", "b"]) == [1 1; 0 1]
        @test sum(confusion(truth, pred, ["a", "b"])) == length(truth)
        @test accuracy(truth, pred) == 2 / 3
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
        function frame(species)
            x = collect(1.0:length(species))
            return DataFrame(;
                species,
                bill_length_mm = x,
                bill_depth_mm = x,
                flipper_length_mm = x,
                body_mass_g = x,
            )
        end
        # a pure node is a leaf
        @test fit_species_clf(frame(fill("Adelie", 30))).tree == AgenticDS.Leaf(1)
        # 19 mixed rows are below minsplit; 20 split at the midpoint of the class boundary
        @test fit_species_clf(frame([fill("Adelie", 10); fill("Gentoo", 9)])).tree isa
              AgenticDS.Leaf
        split20 = fit_species_clf(frame([fill("Adelie", 10); fill("Gentoo", 10)])).tree
        @test split20.var == 1 && split20.cut == 10.5
        # minbucket 7: the clean 24|6 cut is refused, the nearest legal cut is 23|7
        edge = fit_species_clf(frame([fill("Adelie", 24); fill("Gentoo", 6)])).tree
        @test edge.var == 1 && edge.cut == 23.5
        # identical features with mixed labels offer no split
        same = frame([fill("Adelie", 15); fill("Gentoo", 15)])
        same.bill_length_mm .= 1.0
        same.bill_depth_mm .= 1.0
        same.flipper_length_mm .= 1.0
        same.body_mass_g .= 1.0
        @test fit_species_clf(same).tree isa AgenticDS.Leaf
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
        @test gone.objective > km.objective
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
