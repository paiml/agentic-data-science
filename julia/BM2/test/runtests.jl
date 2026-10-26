using BM2
using DataFrames
using JET
using Test

const SCENES = joinpath(@__DIR__, "..", "scenes")
const SRC = joinpath(@__DIR__, "..", "src")

"Run f, return (result, printed text)."
function capture(f)
    path, io = mktemp()
    result = redirect_stdio(f; stdout = io, stderr = io)
    close(io)
    return result, read(path, String)
end

"Read a key = value scene manifest."
function manifest(path)
    pairs = Dict{String,String}()
    for line in eachline(path)
        k, v = split(line, " = "; limit = 2)
        pairs[k] = v
    end
    return pairs
end

"Parse `1-4,6-9` into a vector of (first, last)."
function spans(text)
    return map(split(text, ",")) do s
        a, b = parse.(Int, split(s, "-"))
        return (a, b)
    end
end

const BS = Char(92)
const ROOT =
    abspath(joinpath(@__DIR__, "..", "..", ".."))
const CONTRACT_ID =
    r"ads-(?:julia|r)-[a-z0-9]+(?:-[a-z0-9]+)*-v\d+"

# A .sh launcher must never be typed on camera.
wrapper(cmd) = occursin(".sh", cmd)

# Contract ids named in a text that have no contracts/<id>.yaml.
function dangling(text)
    ids = unique([
        m.match for m in eachmatch(CONTRACT_ID, text)
    ])
    return filter(
        id ->
            !isfile(
                joinpath(ROOT, "contracts", "$id.yaml"),
            ),
        ids,
    )
end

function julia_texts()
    texts = String[]
    for (dir, _, files) in
        walkdir(joinpath(ROOT, "julia"))
        occursin("/.", dir) && continue
        for f in files
            endswith(f, r"\.(jl|ttl|md)") || continue
            push!(texts, read(joinpath(dir, f), String))
        end
    end
    return texts
end

@testset "JET" begin
    JET.test_package(BM2; target_modules = (BM2,))
end

@testset "contract ids" begin
    @test isempty(
        dangling(join(julia_texts(), Char(10))),
    )
    @test dangling("ads-julia-p2-ols-demo-v1") == []
    @test dangling("ads-julia-" * "nope-v1") ==
          ["ads-julia-" * "nope-v1"]
end

@testset "pv lint cache is not tracked" begin
    ignore = readlines(joinpath(ROOT, ".gitignore"))
    @test "contracts/.pv/" in ignore
    tracked = read(
        Cmd(`git ls-files contracts/.pv`; dir = ROOT),
        String,
    )
    @test isempty(tracked)
end

@testset "scene files" begin
    for path in sort(readdir(SCENES; join = true))
        m = manifest(path)
        @testset "$(basename(path))" begin
            src = joinpath(SRC, basename(m["file"]))
            lines = readlines(src)
            @test length(lines) <= 25
            @test all(l -> length(l) <= 56, lines)
            @test !occursin(BS, read(src, String))
            if get(m, "shell", "0") == "1"
                n = length(BM2.V07.GATES)
                @test [m["run$i"] for i = 1:n] == BM2.V07.GATES
                @test !haskey(m, "run$(n + 1)")
                @test !haskey(m, "run")
                @test !haskey(m, "startup")
                @test occursin(
                    "Testing BM2",
                    m["ready"],
                )
            else
                @test m["run"] ==
                      "BM2.$(m["run"][5:7]).main()"
                @test m["startup"] == "using BM2"
            end
            @test parse(Int, m["est_run_s"]) <= (
                endswith(path, "v07-gate.scene") ? 300 :
                90
            )
            ticks = spans(m["ticks"])
            @test 4 <= length(ticks) <= 6
            @test all(t -> 1 <= t[1] <= t[2], ticks)
            @test all(
                i -> ticks[i][2] < ticks[i + 1][1],
                1:(length(ticks) - 1),
            )
            @test ticks[end][2] <= length(lines)
            for (a, b) in ticks
                @test !isempty(lines[a])
                @test !startswith(lines[a], " ")
                @test !startswith(lines[a], "end")
                text = join(lines[a:b], "\n")
                ex = Meta.parseall(text)
                @test !any(
                    e ->
                        e isa Expr &&
                        e.head in (:error, :incomplete),
                    ex.args,
                )
            end
        end
    end
end

@testset "helpers" begin
    df = BM2.load()
    @test nrow(df) == 342
    g = BM2.golden()
    @test BM2.near(1.0, 1.0 + 1e-9)
    @test !BM2.near(1.0, 1.1)
    @test BM2.round3(1.23456) == 1.235
    @test BM2.trim4(1.23456) == 1.2345
    @test BM2.backslash(
        [1.0 0.0; 0.0 2.0],
        [1.0, 4.0],
    ) == [1.0, 2.0]
    X1, X2 = BM2.designs(df)
    @test size(X1) == (342, 2)
    @test size(X2) == (342, 4)
    @test g.ols.slope isa Float64
    ok, out = capture(() -> BM2.contract(true))
    @test ok &&
          out ==
          "contract: ads-julia-p2-ols-demo-v1 OK\n"
    bad, out = capture(() -> BM2.contract(false))
    @test !bad && endswith(out, "FAIL\n")
    ok, out = capture(() -> BM2.verdict(false, "x"))
    @test !ok && out == "x: false\n"
end

"Run the scene's main, return its output lines."
function lines_of(main)
    ok, out = capture(main)
    return ok, readlines(IOBuffer(out))
end

@testset "v01 ticket" begin
    g = BM2.golden()
    @test BM2.V01.beats(g)
    mutated = (; cv_rmse = (; ols = 1.0, species = 2.0))
    @test !BM2.V01.beats(mutated)
    b = BM2.V01.fit_flipper(BM2.load())
    @test isapprox(b[2], 49.6855664061006; atol = 1e-8)
    ok, out = lines_of(BM2.V01.main)
    @test ok &&
          out[end] == "species beats flipper: true"
    @test length(out) <= 4
    @test out[1] ==
          "golden ols: intercept -5780.831, slope 49.686"
    @test out[2] ==
          "golden r2: 0.759 flipper, 0.7826 species"
    @test out[3] ==
          "golden cv_rmse: 394.313 flipper, 376.638 species"
end

@testset "v02 design" begin
    ok, out = lines_of(BM2.V02.main)
    @test ok && out[end] == "design matrices: true"
    @test out[1] == "rows 342, X is 342 x 2"
    @test out[end - 1] ==
          "dummy sums: 68, 123; Adelie 151"
    @test length(out) <= 6
    df = BM2.load()
    @test BM2.V02.baseline(df) == 151
    @test size(BM2.V02.species_dummies(df)) == (342, 3)
end

@testset "v03 red first" begin
    ok, out = lines_of(BM2.V03.main)
    @test ok && out[end] == "red, then green: true"
    @test out[1] == "red: ols is not defined"
    @test out[2] == "green: 2 of 2 tests pass"
    # can fail: with ols present the red step is no error
    scratch = Module(:S)
    Core.eval(scratch, Expr(:(=), :ols, BM2.V03.ols))
    @test BM2.red(BM2.V03.check, scratch) == 2
    # can fail: a wrong ols turns the check red
    wrong = Module(:W)
    Core.eval(
        wrong,
        Expr(
            :(=),
            :ols,
            (x, y) -> (; intercept = 0.0, slope = 0.0),
        ),
    )
    @test invokelatest(BM2.V03.check, wrong) == 0
end

@testset "v05 folds" begin
    ok, out = lines_of(BM2.V05.main)
    @test ok && out[end] == "golden: true"
    @test out[1] == "fold sizes: [69, 69, 68, 68, 68]"
    @test length(out) <= 4
    df = BM2.load()
    X1, X2 = BM2.designs(df)
    y, folds = df.body_mass_g, BM2.read_folds()
    g = BM2.golden().cv_rmse
    @test isapprox(
        BM2.V05.cv_rmse(X1, y, folds),
        g.ols;
        atol = 1e-6,
    )
    @test isapprox(
        BM2.V05.cv_rmse(X2, y, folds),
        g.species;
        atol = 1e-6,
    )
    # can fail: other folds change the answer
    other = mod.(folds, 3) .+ 1
    @test !isapprox(
        BM2.V05.cv_rmse(X1, y, other),
        g.ols;
        atol = 1e-6,
    )
    ins = BM2.V05.insample(X1, y)
    @test isapprox(ins, 393.124; atol = 5e-4)
    @test out[2] == "in-sample rmse: 393.124"
    @test ins < BM2.V05.cv_rmse(X1, y, folds)
end

@testset "v06 mlj" begin
    ok, out = lines_of(BM2.V06.main)
    @test ok && out[end] == "golden: true"
    @test out[1] == "before fit!: fitted = false"
    @test length(out) <= 6
    df = BM2.load()
    mach = BM2.V06.make_machine(df)
    BM2.V06.fit!(mach; verbosity = 0)
    @test BM2.V06.matches_golden(mach)
    names = first.(
        BM2.named_params(BM2.V06.fitted_params(mach)),
    )
    @test names == [
        "(Intercept)",
        "flipper_length_mm",
        "speciesChinstrap",
        "speciesGentoo",
    ]
    # can fail: a machine on the flipper-only table has other coefficients
    X = df[:, [:flipper_length_mm]]
    flat = BM2.V06.machine(
        BM2.V06.LinearRegressor(),
        X,
        df.body_mass_g,
    )
    BM2.V06.fit!(flat; verbosity = 0)
    p = BM2.V06.fitted_params(flat)
    @test length(p.coefs) == 1
    @test !BM2.V06.matches_golden(flat)
    # matched by name: order does not matter, a wrong name does
    got = BM2.named_params(BM2.V06.fitted_params(mach))
    gold = BM2.golden().species_model
    @test BM2.same_params(reverse(got), gold)
    renamed = [got[1]; "x" => got[2][2]; got[3:end]]
    @test !BM2.same_params(renamed, gold)
    @test !BM2.same_params(got[1:3], gold)
end

# The v07 commands run in gate/v07.jl, after this suite, so
# this suite holds no test that starts itself.
@testset "v07 gate data" begin
    g = BM2.V07.GATES
    @test length(g) == 2
    @test startswith(
        g[1],
        "julia --project=julia/gate -e '",
    )
    @test endswith(g[1], "' julia/BM2")
    @test occursin("exit(ok ? 0 : 1)", g[1])
    @test !any(wrapper, g)
    @test wrapper("scripts/julia-format.sh julia/BM2")
    @test g[2] ==
          "julia --project=julia/BM2 -e 'using Pkg; Pkg.test()'"
    m = manifest(joinpath(SCENES, "v07-gate.scene"))
    @test m["run1"] == g[1]
    @test parse(Int, m["repl_rows"]) == 16
end

@testset "v08 mutants" begin
    ok, out = lines_of(BM2.V08.main)
    @test ok && out[end] == "caught: true"
    @test out[1] == "leak: 2 of 2 checks fail"
    @test length(out) <= 4
    df, folds = BM2.load(), BM2.read_folds()
    # the honest cross-validation passes both checks
    @test BM2.V08.fails(df, folds, BM2.honest) == 0
    # can fail: every mutant fails at least one check
    @test BM2.V08.fails(df, folds, BM2.V08.leak) == 2
    @test BM2.V08.fails(df, folds, BM2.V08.nobias) == 2
    @test BM2.V08.fails(
        df,
        mod.(folds, 3) .+ 1,
        BM2.honest,
    ) == 2
end

@testset "v09 examples" begin
    ok, out = lines_of(BM2.V09.main)
    @test ok && out[end] == "examples: true"
    @test out[1] ==
          "(intercept = -5780.8313, slope = 49.6855)"
    @test out[2] ==
          "contract: ads-julia-p2-ols-demo-v1 OK"
    @test out[3] ==
          "coefs = [-4031.4768, 40.7054, -206.5101, 266.8096]"
    @test out[4] == "cv_rmse (ols): 394.3129"
    @test out[5] == "cv_rmse (species): 376.6382"
    @test length(out) <= 7
end

@testset "v10 wrap-up" begin
    ok, out = lines_of(BM2.V10.main)
    @test ok && out[end] == "wrap-up: true"
    @test length(out) == 3
    @test all(startswith("contract:"), out[1:2])
    text = BM2.V10.quiet(BM2.V09.ols_example)
    @test BM2.V10.keep(text) ==
          ["contract: ads-julia-p2-ols-demo-v1 OK"]
    # can fail: a failing line or a wrong count is rejected
    @test !BM2.V10.good(["contract: x OK"])
    @test !BM2.V10.good([
        "contract: x OK",
        "contract: y FAIL",
    ])
    @test BM2.V10.good([
        "contract: x OK",
        "contract: y OK",
    ])
    # a third line is rejected
    @test !BM2.V10.good(fill("contract: x OK", 3))
end
