using BM4
using DataFrames
using JET
using Test

const SRC = joinpath(@__DIR__, "..", "src")
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

# What an example's main() prints, as lines.
function output(f)
    path = tempname()
    open(path, "w") do io
        redirect_stdout(f, io)
    end
    return readlines(path)
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

@testset "example $(NAMES[i])" for i in eachindex(NAMES)
    name = NAMES[i]
    file =
        joinpath(SRC, replace(name, "-" => "_") * ".jl")
    text = read(file, String)

    @testset "file" begin
        @test isfile(file)
        @test !occursin(Char(92), text)
        @test !occursin(Char(27), text)
    end

    @testset "run output" begin
        out = output(MAINS[i])
        @test !isempty(out)
        @test all(l -> length(l) <= 60, out)
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
