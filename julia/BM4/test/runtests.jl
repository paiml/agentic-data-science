using BM4
using DataFrames
using JET
using Test

const SRC = joinpath(@__DIR__, "..", "src")
const SCENES = joinpath(@__DIR__, "..", "scenes")
const NAMES = [
    "v01-ticket",
    "v02-ingest",
    "v03-split",
    "v04-pipeline",
    "v05-leak",
    "v06-report",
    "v07-gates",
    "v08-bench",
    "v09-examples",
    "v10-wrapup",
]
const MAINS = [
    BM4.V01.main,
    BM4.V02.main,
    BM4.V03.main,
    BM4.V04.main,
    BM4.V05.main,
    BM4.V06.main,
    BM4.V07.main,
    BM4.V08.main,
    BM4.V09.main,
    BM4.V10.main,
]

# key = value manifest -> Dict
function manifest(name)
    d = Dict{String,String}()
    for line in
        eachline(joinpath(SCENES, name * ".scene"))
        k, v = split(line, " = "; limit = 2)
        d[k] = v
    end
    return d
end

# What a scene's main() prints, as lines.
function output(f)
    path = tempname()
    open(path, "w") do io
        redirect_stdout(f, io)
    end
    return readlines(path)
end

# (first line, last line) of each top-level unit.
function units(text)
    lines = split(text, '\n')
    ends = findall(==('\n'), text)
    lineof(p) = count(<(p), ends) + 1
    out = Tuple{Int,Int}[]
    pos = 1
    while pos <= lastindex(text)
        e, nxt = Meta.parse(text, pos; greedy = true)
        e === nothing && break
        first = findfirst(!isspace, text[pos:end])
        a = lineof(first + pos - 1)
        b = lineof(max(nxt - 1, pos))
        while b > a && isempty(strip(lines[b]))
            b -= 1
        end
        push!(out, (a, b))
        pos = nxt
    end
    return out
end

function ticks(s)
    pairs = [
        parse.(Int, split(t, '-')) for
        t in split(s, ',')
    ]
    return [(p[1], p[2]) for p in pairs]
end

@testset "JET" begin
    JET.test_package(BM4; target_modules = (BM4,))
end

@testset "golden file (ads-julia-p4-v1)" begin
    g = BM4.golden()
    @test (g.rows, g.train, g.test) ==
          (6497, 5198, 1299)
    @test isapprox(
        g.rmse,
        0.760251606190075;
        atol = 1e-12,
    )
    @test isapprox(g.r2, 0.25985449136456; atol = 1e-12)
    r = BM4.V04.pipeline_wine(BM4.RED, BM4.WHITE)
    @test isapprox(r.rmse, g.rmse; atol = 1e-6)
    @test isapprox(r.r2, g.r2; atol = 1e-6)
    @test (r.rows, r.train, r.test) ==
          (6497, 5198, 1299)
end

@testset "scene $(NAMES[i])" for i in eachindex(NAMES)
    name = NAMES[i]
    m = manifest(name)
    file = joinpath(SRC, basename(m["file"]))
    text = read(file, String)
    lines = split(chomp(text), '\n')
    rows = parse(Int, m["repl_rows"])

    @testset "manifest" begin
        @test m["startup"] == "using BM4"
        @test m["run"] == "BM4.V$(name[2:3]).main()"
        @test m["plot"] == "none"
        @test parse(Int, m["est_run_s"]) <= 90
        @test m["file"] ==
              "src/" * replace(name, "-" => "_") * ".jl"
        @test haskey(m, "ready")
    end

    @testset "shown file limits" begin
        @test length(lines) <= 36 - rows
        @test all(l -> length(l) <= 56, lines)
        @test !occursin(Char(92), text)
        @test !occursin(Char(27), text)
    end

    @testset "ticks are forward whole top-level units" begin
        t = ticks(m["ticks"])
        u = units(text)
        @test 4 <= length(t) <= 6
        @test all(x -> x[1] <= x[2], t)
        @test issorted(first.(t))
        @test all(
            i -> t[i][2] < t[i + 1][1],
            1:(length(t) - 1),
        )
        for (a, b) in t
            @test any(x -> x[1] == a, u)
            @test any(x -> x[2] == b, u)
        end
        covered =
            Set(Iterators.flatten(a:b for (a, b) in t))
        for (i, l) in enumerate(lines)
            i in covered && continue
            @test isempty(strip(l)) ||
                  startswith(strip(l), "#")
        end
    end

    @testset "run output" begin
        out = output(MAINS[i])
        @test length(out) <= rows - 3
        @test all(l -> length(l) <= 60, out)
        @test last(out) == m["ready"]
        @test !any(contains("Warning"), out)
    end
end

@testset "can fail" begin
    df = BM4.V02.read_wine(BM4.RED, BM4.WHITE)
    g = BM4.golden()

    @testset "validate_wine refuses each bad table" begin
        for (label, col, v, want) in BM4.BAD
            bad = BM4.with(df, col, v)
            @test BM4.refusal(
                BM4.V02.validate_wine,
                bad,
            ) == want
        end
        @test BM4.refusal(identity, df) == "accepted"
        @test BM4.V02.validate_wine(df) === df
        @test !BM4.refuse_all(x -> x, df)
        out = output(BM4.V02.main)
        @test "clean table passes: true" in out
        @test last(out) ==
              "contract: b-m4 validate_wine refuses 3 bad tables OK"
    end

    @testset "naive split fails, fifth-row split passes" begin
        s = BM4.V03.split_wine(df)
        @test BM4.V03.want(df, s)
        @test !BM4.V03.want(df, BM4.V03.naive(df))
        @test nrow(s.train) + nrow(s.test) == nrow(df)
    end

    @testset "compare and near" begin
        out = output(
            () -> @test !BM4.compare("x", 1.0, 1.1)
        )
        @test occursin("golden", only(out))
        @test BM4.near(1.0, 1.0 + 1e-9)
        @test !BM4.near(1.0, 1.001)
    end

    @testset "leaky fit is caught by every check" begin
        leaky = BM4.V05.run_mutant(
            BM4.V05.mutate(BM4.V05.V04_FILE),
        )
        res = BM4.V05.suite(leaky, g)
        @test all(p -> !last(p), res)
        @test leaky.rmse < g.rmse
        ok = BM4.V05.suite(
            BM4.V04.pipeline_wine(BM4.RED, BM4.WHITE),
            g,
        )
        @test first(ok[1]) == "rmse golden"
        @test last(ok[1]) && last(ok[2]) && last(ok[4])
    end

    @testset "report differs when the numbers differ" begin
        r = BM4.V04.pipeline_wine(BM4.RED, BM4.WHITE)
        good = BM4.V06.report_ttl(r, tempname())
        @test BM4.V06.same_ttl(good, BM4.R_TTL)
        off = (; r..., rmse = 0.5)
        bad = BM4.V06.report_ttl(off, tempname())
        @test !BM4.V06.same_ttl(bad, BM4.R_TTL)
        @test BM4.V07.shapes_ok(good)
        @test !BM4.V07.shapes_ok(BM4.SHAPES)
    end

    @testset "checksums" begin
        dir = mktempdir()
        write(joinpath(dir, "f.txt"), "x")
        write(joinpath(dir, "LICENSE"), "")
        write(joinpath(dir, "SHA256SUMS"), "0 f.txt\n")
        @test !BM4.V07.sums_ok(dir)
        @test BM4.V07.sums_ok("wine-quality")
        @test !BM4.V01.verify("0 winequality-red.csv")
        @test BM4.V01.rows(BM4.RED) == 1599
        # a table with a zero-byte LICENSE is refused
        h = bytes2hex(BM4.V07.sha256("x"))
        write(joinpath(dir, "SHA256SUMS"), "$h f.txt\n")
        @test !BM4.V07.sums_ok(dir)
    end

    @testset "aggregates agree, and disagree when changed" begin
        a = BM4.V08.aggregate_groupby(df)
        b = BM4.V08.aggregate_loop(df)
        @test BM4.agree(a, b)
        c = copy(b)
        c.n[1] += 1
        @test !BM4.agree(a, c)
        @test all(>(0), BM4.V08.bench_wine(df))
    end

    @testset "verdict and claim colours" begin
        out = output(() -> BM4.verdict(false, "x"))
        @test only(out) == "contract: b-m4 x FAIL"
        out = output(() -> BM4.failed("y"))
        @test only(out) == "FAIL y"
        out = output(() -> BM4.claim(false, "z"))
        @test only(out) == "FAIL z"
        out = output(() -> BM4.table(DataFrame(a = 1)))
        @test !isempty(out)
    end

    @testset "examples keep their contracts" begin
        out = BM4.V09.pipeline_example(IOBuffer())
        @test out === nothing
        lines = BM4.captured(BM4.V09.pipeline_example)
        @test last(lines) == BM4.V09.OK
        @test any(BM4.V09.shown, lines)
        @test !BM4.V09.shown("rmse")
    end
end
