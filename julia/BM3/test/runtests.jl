using BM3
using DataFrames
using JET
using Statistics
using Test

const PKG = pkgdir(BM3)
const REPO = normpath(joinpath(PKG, "..", ".."))
const G = BM3.GOLD
const CONTRACT_ID =
    r"ads-(?:julia|r)-[a-z0-9]+(?:-[a-z0-9]+)*-v\d+"

# Contract ids named in a text that have no contracts/<id>.yaml.
function dangling(text)
    ids = unique([
        m.match for m in eachmatch(CONTRACT_ID, text)
    ])
    return filter(
        id ->
            !isfile(
                joinpath(REPO, "contracts", "$id.yaml"),
            ),
        ids,
    )
end

function julia_texts()
    texts = String[]
    for (dir, _, files) in
        walkdir(joinpath(REPO, "julia"))
        occursin("/.", dir) && continue
        for f in files
            endswith(f, r"\.(jl|ttl|md)") || continue
            push!(texts, read(joinpath(dir, f), String))
        end
    end
    return texts
end

# --- example gate: file checks, run output ---------------
function capture(f)
    out, err = tempname(), tempname()
    open(out, "w") do o
        open(err, "w") do e
            redirect_stdout(o) do
                redirect_stderr(f, e)
            end
        end
    end
    return read(out, String), read(err, String)
end

function example_gate(id, mod, modname; tool = false)
    path = joinpath(
        PKG,
        "src",
        replace(id, "-" => "_") * ".jl",
    )
    text = read(path, String)
    @testset "$id file" begin
        @test !occursin('\\', text)
        @test !occursin('\e', text)
        @test !occursin('\t', text)
        @test isdefined(mod, :GATES) ||
              isdefined(mod, :main)
    end
    tool || @testset "$id run" begin
        (out, err) = capture(mod.main)
        shown = split(chomp(out), "\n")
        @test err == ""
        @test !isempty(shown[end])
        @test endswith(shown[end], ": true")
        @test !occursin("Warning", out)
    end
    return nothing
end

@testset "BM3 suite" begin
    @testset "contract ids" begin
        @test isempty(
            dangling(join(julia_texts(), Char(10))),
        )
        @test dangling("ads-r-p3-v1") == []
        @test dangling("ads-julia-" * "nope-v1") ==
              ["ads-julia-" * "nope-v1"]
    end

    @testset "pv lint cache is not tracked" begin
        ignore = readlines(joinpath(REPO, ".gitignore"))
        @test "contracts/.pv/" in ignore
        tracked = read(
            Cmd(
                `git ls-files contracts/.pv`;
                dir = REPO,
            ),
            String,
        )
        @test isempty(tracked)
    end

    @testset "JET" begin
        JET.test_package(BM3; target_modules = (BM3,))
    end

    @testset "fixtures and golden" begin
        json = read(BM3.datapath("p3.json"), String)
        num(key) = parse(
            Float64,
            match(Regex("\"$key\": ([0-9.]+)"), json)[1],
        )
        ints(s) = parse.(Int, split(s, ","))
        rows = [
            ints(m[1]) for m in
            eachmatch(r"\[(\d+, \d+, \d+)\]", json)
        ]
        sizes = ints(
            match(
                r"cluster_sizes\": \[([\d, ]+)\]",
                json,
            )[1],
        )
        @test G.accuracy == num("accuracy")
        @test G.confusion == reduce(hcat, rows[1:3])'
        @test G.classes ==
              ["Adelie", "Chinstrap", "Gentoo"]
        @test G.objective == num("objective")
        @test G.sizes == sizes
        for (src, name) in (
            (
                "datasets/penguins/penguins.csv",
                "penguins.csv",
            ),
            (
                "datasets/fixtures/split.csv",
                "split.csv",
            ),
            (
                "datasets/fixtures/centroids.csv",
                "centroids.csv",
            ),
            ("datasets/golden/p3.json", "p3.json"),
        )
            @test read(joinpath(REPO, src)) ==
                  read(BM3.datapath(name))
        end
        sums = read(BM3.datapath("SHA256SUMS"), String)
        @test startswith(sums, BM3.SHA_PENGUINS)
        @test BM3.checksum_ok()
        @test nrow(BM3.penguins()) == 342
        @test size(BM3.centroids()) == (3, 4)
    end

    @testset "v01-ticket" begin
        example_gate("v01-ticket", BM3.V01, "V01")
        t = BM3.task()
        @test BM3.V01.ticket_data(t)
        @test BM3.V01.ticket_confusion(G)
        @test BM3.V01.ticket_kmeans(G)
        @testset "can fail: a wrong fixture is rejected" begin
            short = (;
                y = t.y[1:300],
                train = t.train,
                test = t.test,
            )
            bad = (; G..., sizes = [133, 123, 85])
            skew = (;
                G...,
                confusion = [37 0 0; 0 15 2; 0 1 30],
            )
            out = capture() do
                @test !BM3.V01.ticket_data(short)
                @test !BM3.V01.ticket_kmeans(bad)
                @test !BM3.V01.ticket_confusion(skew)
            end
        end
    end

    @testset "v02-features" begin
        example_gate("v02-features", BM3.V02, "V02")
        X = BM3.task().X
        z = BM3.V02.zscore(X)
        @test size(z) == (342, 4)
        @test all(abs.(mean(z; dims = 1)) .< 1e-12)
        @test all(abs.(std(z; dims = 1) .- 1) .< 1e-12)
        @test round.(mean(X; dims = 1); digits = 2) ==
              [43.92 17.15 200.92 4201.75]
        @test round.(std(X; dims = 1); digits = 2) ==
              [5.46 1.97 14.06 801.95]
        capture() do
            @test isapprox(
                BM3.V02.body_share(X),
                0.9894;
                atol = 5e-5,
            )
        end
        @testset "can fail: raw columns are not z-scored" begin
            @test !all(abs.(mean(X; dims = 1)) .< 1e-12)
            @test !all(
                abs.(std(X; dims = 1) .- 1) .< 1e-12,
            )
            # swapping rows changes the share: it is a property of the pair
            capture() do
                @test BM3.V02.body_share(
                    X[[3, 4, 1, 2], :],
                ) != BM3.V02.body_share(X)
            end
        end
    end

    @testset "v03-split" begin
        example_gate("v03-split", BM3.V03, "V03")
        cut = BM3.V03.best_cut
        x = [1.0, 2.0, 3.0, 10.0, 11.0, 12.0]
        @test BM3.V03.gini([3, 3]) == 3.0
        @test BM3.V03.gini([6, 0]) == 0.0
        @test cut(x, [1, 1, 1, 2, 2, 2]) == (3.0, 6.5)
        @test cut(x, [2, 2, 2, 1, 1, 1]) == (3.0, 6.5)
        @testset "tie: the first of two equal cuts wins" begin
            gain, c =
                cut([1.0, 2.0, 3.0, 4.0], [1, 2, 1, 2])
            @test c == 1.5
            @test isapprox(gain, 2 / 3; atol = 1e-12)
        end
        @testset "equal values offer no cut between them" begin
            none =
                cut([1.0, 1.0, 1.0, 1.0], [1, 2, 1, 2])
            @test none[1] == 0.0 && isnan(none[2])
            @test cut(
                [1.0, 1.0, 2.0, 2.0],
                [1, 1, 2, 2],
            )[2] == 1.5
        end
        @testset "minbucket keeps both pieces large enough" begin
            y = [fill(1, 24); fill(2, 6)]
            v = collect(1.0:30.0)
            @test cut(v, y)[2] == 24.5
            @test cut(v, y; minbucket = 7)[2] == 23.5
        end
        @testset "can fail: other labels move the cut" begin
            @test cut(x, [1, 2, 1, 2, 1, 2])[2] != 6.5
        end
    end

    @testset "v04-tree" begin
        example_gate("v04-tree", BM3.V04, "V04")
        t = BM3.task()
        rows = findall(t.train)
        tree = BM3.fit_tree(t)
        @test BM3.outline(tree) ==
              ((3, 207.5), (1, 43.35))
        @test BM3.score(tree, t) == (83, 85)
        @test BM3.settings() ==
              "minsplit 20, minbucket 7, cp 0.01"
        @test BM3.V04.counts(t.y, rows) == [114, 51, 92]
        out, _ = capture(() -> BM3.show_tree(tree))
        @test out ==
              "flipper_length_mm < 207.5\n" *
              "  bill_length_mm < 43.35: Adelie\n" *
              "  else: Chinstrap\nelse: Gentoo\n"
        @testset "no usable cut gives a leaf" begin
            X = zeros(30, 4)
            y = repeat([1, 2], 15)
            leaf, err = BM3.V04.grow(X, y, 1:30, 30)
            @test leaf isa BM3.Leaf && err == 15
            @test BM3.best_split(X, y, 1:30).var == 0
        end
        @testset "can fail: pruning everything or a stump" begin
            cut, _ = BM3.V04.grow(t.X, t.y, rows, 1e6)
            @test cut isa BM3.Leaf
            stump = BM3.Split(
                3,
                207.5,
                BM3.Leaf(1),
                BM3.Leaf(3),
            )
            @test BM3.score(stump, t)[1] < 83
            out, _ = capture() do
                @test !BM3.V04.report(stump)
            end
            @test occursin(
                "golden 0.976470588235294",
                out,
            )
            out, _ = capture(() -> BM3.show_tree(cut))
            @test out == "Adelie\n" || out == "Gentoo\n"
        end
    end

    @testset "v05-confusion" begin
        example_gate("v05-confusion", BM3.V05, "V05")
        t = BM3.task()
        pred =
            BM3.predict(BM3.fit_tree(t), t.X[t.test, :])
        truth = t.y[t.test]
        cm = BM3.V05.confusion(truth, pred)
        @test cm == G.confusion
        @test sum(cm) == 85
        @test round.(BM3.V05.recall(cm); digits = 4) ==
              [1.0, 0.9412, 0.9677]
        @test round.(
            BM3.V05.precision(cm);
            digits = 4,
        ) == [1.0, 0.9412, 0.9677]
        @testset "can fail: one moved bird changes the matrix" begin
            moved = copy(pred)
            moved[findfirst(==(3), moved)] = 1
            @test BM3.V05.confusion(truth, moved) !=
                  G.confusion
            @test BM3.V05.recall(
                BM3.V05.confusion(truth, moved),
            ) != BM3.V05.recall(cm)
        end
    end

    @testset "v06-kmeans" begin
        example_gate("v06-kmeans", BM3.V06, "V06")
        z, c = BM3.scaled()
        @test size(z) == (342, 4) && length(c) == 3
        @test all(abs.(mean(z; dims = 1)) .< 1e-12)
        lab, obj = BM3.V06.lloyd(z, c)
        _, one = BM3.V06.lloyd(z, c; iters = 1)
        @test isapprox(obj, G.objective; atol = 1e-9)
        @test [count(==(k), lab) for k = 1:3] == G.sizes
        @test round(one; digits = 4) == 394.3003
        @test one >= obj
        @test BM3.V06.objective(z, c, lab) >= obj - 1e-9
        @test BM3.sq([1.0, 2.0], [0.0, 0.0]) == 5.0
        @testset "an empty cluster keeps its centre" begin
            old = [1.0, 2.0]
            @test BM3.V06.centre(zeros(0, 2), old) ==
                  old
            @test BM3.V06.centre(
                [1.0 3.0; 3.0 5.0],
                old,
            ) == [2.0, 4.0]
        end
        @testset "can fail: without the update the start stays" begin
            lab0 = [
                argmin([BM3.sq(r, a) for a in c])
                for r in eachrow(z)
            ]
            @test BM3.V06.objective(z, c, lab0) > obj
        end
    end

    # The checks of the gates example live in this suite.
    tree_ok() = BM3.score(BM3.fit_tree()) == (83, 85)
    function kmeans_ok()
        z, c = BM3.scaled()
        return BM3.V06.lloyd(z, c)[2] ≈ G.objective
    end

    @testset "golden parity" begin
        @test tree_ok()
        @test kmeans_ok()
    end

    # v07 holds shell commands as data. This suite does not run
    # them, so it never starts itself.
    @testset "v07-gates" begin
        example_gate(
            "v07-gates",
            BM3.V07,
            "V07";
            tool = true,
        )
        gates = BM3.V07.GATES
        @test length(gates) == 2
        @test startswith(
            first(gates),
            "julia --project=julia/gate -e '",
        )
        @test endswith(first(gates), "' julia/BM3")
        @test !any(c -> occursin(".sh", c), gates)
        @test last(gates) ==
              "julia --project=julia/BM3 -e 'using Pkg; Pkg.test()'"
    end

    @testset "v08-mutants" begin
        example_gate("v08-mutants", BM3.V08, "V08")
        V = BM3.V08
        @test V.no_update() && V.later_tie()
        @test_throws ErrorException V.mut(
            "v03_split",
            "zzz",
            "y",
        )
        @testset "can fail: a harmless change survives" begin
            go = V.mut(
                "v03_split",
                "gain > b",
                "gain > b",
            )
            @test go(:best_cut, 1.0:4, [1, 2, 1, 2])[2] ==
                  1.5
            same =
                V.mut("v06_kmeans", "mean(A", "mean(A")
            z, c = BM3.scaled()
            @test same(:lloyd, z, c)[2] ≈ G.objective
            out, _ = capture(
                () -> BM3.hit_line("name", false),
            )
            @test occursin("SURVIVED", out)
        end
    end

    @testset "v09-examples" begin
        example_gate("v09-examples", BM3.V09, "V09")
        V = BM3.V09
        t = BM3.task()
        cm = V.matrix(t)
        @test cm == G.confusion && V.hits(cm) == 83
        out, _ = capture(V.tree_part)
        @test occursin(
            "confusion: [37 0 0; 0 16 1; 0 1 30]",
            out,
        )
        @test occursin(
            "accuracy: 0.9764705882352941",
            out,
        )
        out, _ = capture(V.kmeans_part)
        @test occursin(
            "cluster sizes: [133, 123, 86]",
            out,
        )
        @testset "can fail: a moved prediction" begin
            bad = copy(cm)
            bad[3, 3] -= 1
            bad[3, 1] += 1
            @test bad != G.confusion &&
                  V.hits(bad) == 82
        end
    end

    @testset "v10-wrapup" begin
        example_gate("v10-wrapup", BM3.V10, "V10")
        V = BM3.V10
        @test V.tree_ok() && V.kmeans_ok()
        @testset "can fail: a false result prints FAILED" begin
            out, _ = capture(() -> BM3.contract(false))
            @test occursin("FAILED", out)
            g = (; G..., accuracy = 0.5)
            out, _ = capture(() -> V.golden_line(g))
            @test startswith(
                out,
                "golden accuracy 0.5, ",
            )
        end
        out, _ = capture(() -> V.golden_line())
        @test occursin(
            "k-means 378.2936 / [133, 123, 86]",
            out,
        )
    end
end
