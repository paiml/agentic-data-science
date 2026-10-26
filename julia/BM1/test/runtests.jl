using BM1
using DataFrames
using JET
using Test

const PKG = dirname(@__DIR__)
const SCENES = [
    ("v01", "ticket", BM1.V01),
    ("v02", "ingest", BM1.V02),
    ("v03", "generate", BM1.V03),
    ("v04", "profile", BM1.V04),
    ("v05", "green", BM1.V05),
    ("v06", "json", BM1.V06),
    ("v07", "gates", BM1.V07),
    ("v08", "mutants", BM1.V08),
    ("v09", "parse", BM1.V09),
    ("v10", "wrapup", BM1.V10),
]
const CSV_PATH = joinpath(PKG, "data", "penguins.csv")
const OUT = Dict{String,String}()
function manifest(id, name)
    path = joinpath(PKG, "scenes", "$id-$name.scene")
    pairs = map(eachline(path)) do line
        k, v = split(line, " = "; limit = 2)
        return k => v
    end
    return Dict(pairs)
end

function scene_lines(m)
    return readlines(joinpath(PKG, m["file"]))
end

# Start line of every top-level statement of a file.
function starts(m)
    path = joinpath(PKG, m["file"])
    top = Meta.parseall(read(path, String))
    nodes = filter(x -> x isa LineNumberNode, top.args)
    return [n.line for n in nodes]
end

function ticks(m)
    spans = split(m["ticks"], ",")
    return [parse.(Int, split(s, "-")) for s in spans]
end

# Run main() once per scene with stdout and stderr captured.
function output(id, mod)
    return get!(OUT, id) do
        BM1.capture(() -> Base.invokelatest(mod.main))
    end
end

function out_lines(id, mod)
    return split(rstrip(output(id, mod)), Char(10))
end

# A .sh launcher must never be typed on camera.
wrapper(cmd) = occursin(".sh", cmd)

# Tick starts that vim maps to F2..F9 for a scene file.
function vim_ticks(m)
    out = tempname()
    expr =
        """call writefile(map(range(2, 9), {_, i ->""" *
        """ maparg("<F" . i . ">", "n")}), '$out')"""
    cmd = `vim -u $(joinpath(PKG, "vimrc.demo")) -es -N
        --not-a-term $(joinpath(PKG, m["file"]))
        -c $expr -c qa!`
    run(
        pipeline(
            cmd;
            stdout = devnull,
            stderr = devnull,
        ),
    )
    maps = readlines(out)
    calls = [match(r"Tick\((\d+)\)", x) for x in maps]
    return [
        parse(Int, c[1]) for c in calls if c !== nothing
    ]
end

const ROOT = dirname(dirname(PKG))
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

function tmp_penguins()
    return BM1.AgenticDS.read_penguins(CSV_PATH)
end

function scratch_file()
    file = joinpath(mktempdir(), "Scratch.jl")
    write(file, "module Scratch\nhello(x) = x\nend\n")
    return file
end

@testset "BM1 suite" begin
    @testset "JET" begin
        mods = (
            BM1,
            BM1.V01,
            BM1.V02,
            BM1.V03,
            BM1.V04,
            BM1.V05,
            BM1.V06,
            BM1.V07,
            BM1.V08,
            BM1.V09,
            BM1.V10,
        )
        JET.test_package(BM1; target_modules = mods)
    end

    @testset "scene files" begin
        for (id, name, mod) in SCENES
            @testset "$id layout" begin
                m = manifest(id, name)
                src = scene_lines(m)
                text = join(src, Char(10))
                @test length(src) <= 25
                @test maximum(length.(src)) <= 56
                @test !occursin(Char(92), text)
                @test m["file"] == "src/$(id)_$name.jl"
                if id == "v07"
                    @test m["shell"] == "1"
                    @test !haskey(m, "run")
                else
                    @test m["startup"] == "using BM1"
                    @test m["run"] ==
                          "BM1.$(uppercase(id)).main()"
                end
                @test m["plot"] == "none"
                @test parse(Int, m["est_run_s"]) <=
                      (id == "v07" ? 300 : 90)

                t = ticks(m)
                s = starts(m)
                @test 4 <= length(t) <= 6
                @test issorted(first.(t))
                @test all(x -> x[1] <= x[2], t)
                @test all(
                    i -> t[i][2] < t[i + 1][1],
                    1:(length(t) - 1),
                )
                @test all(x -> x[1] in s, t)
                ends = vcat(s, length(src) + 1)
                @test all(x -> x[2] + 1 in ends, t)
                @test t[1][1] == 1
                @test t[end][2] == length(src)

                @testset "vimrc.demo ticks equal the manifest" begin
                    @test vim_ticks(m) == first.(t)
                end
            end
        end

        @testset "vimrc.demo holds no hard-coded tick" begin
            rc = read(
                joinpath(PKG, "vimrc.demo"),
                String,
            )
            hard = r"call Tick\(\d+\)"
            @test !occursin(hard, rc)
            @test occursin(
                hard,
                "<F2> <Cmd>call Tick(3)<CR>",
            )
        end
    end

    @testset "contract ids" begin
        @test isempty(
            dangling(join(julia_texts(), Char(10))),
        )
        @test dangling("ads-julia-p1-v1") == []
        @test dangling("ads-julia-" * "nope-v1") ==
              ["ads-julia-" * "nope-v1"]
    end

    @testset "pv lint cache is not tracked" begin
        ignore = readlines(joinpath(ROOT, ".gitignore"))
        @test "contracts/.pv/" in ignore
        tracked = read(
            Cmd(
                `git ls-files contracts/.pv`;
                dir = ROOT,
            ),
            String,
        )
        @test isempty(tracked)
    end

    @testset "run output" begin
        for (id, name, mod) in SCENES
            id == "v07" && continue
            @testset "$id output" begin
                m = manifest(id, name)
                rows = parse(Int, m["repl_rows"])
                lines = out_lines(id, mod)
                all_text = join(lines, Char(10))
                @test length(lines) <= rows - 3
                @test !occursin("Warning", all_text)
                @test !occursin("Info", all_text)
                @test !occursin(
                    "Precompiling",
                    all_text,
                )
                @test !occursin("\e[", all_text)
                @test last(lines) == m["ready"]
                @test length(m["ready"]) <= 59
                @test startswith(
                    last(lines),
                    "contract: ",
                )
                @test endswith(last(lines), " OK")
            end
        end
    end

    @testset "verdict" begin
        out = BM1.capture() do
            @test BM1.verdict(true, "fine") == true
            @test BM1.verdict(false, "broken") == false
        end
        @test occursin("contract: b-m1 fine OK", out)
        @test occursin(
            "contract: b-m1 broken FAILED",
            out,
        )
    end

    @testset "helpers" begin
        @test BM1.golden().species.Adelie.n == 151
        @test BM1.capture(() -> println("hi")) == "hi\n"
        @test BM1.capture_cmd(`echo cmd`) == "cmd\n"
        @test BM1.julia_cmd("d", "-e", "1") isa Cmd
        @test BM1.shown("  Test Failed at x  1.2s") ==
              ["Test Failed at x"]
        @test BM1.shown("hello | 1 1  0.5s") ==
              ["hello | 1 1"]
        @test BM1.shown("Test Summary: | Pass") ==
              ["Test Summary: | Pass"]
        @test isempty(BM1.shown("Stacktrace:"))
        @test isempty(BM1.shown("  [1] error()"))
    end

    @testset "v01 ticket" begin
        out = output("v01", BM1.V01)
        @test occursin("penguins.csv: OK", out)
        @test occursin(
            "raw rows 344, dropped 2, clean 342",
            out,
        )
        @test occursin(
            "golden n: [151, 123, 68] sums to 342",
            out,
        )

        @testset "can fail: a dropped row breaks the oracle" begin
            raw = tmp_penguins()
            clean = BM1.AgenticDS.na_policy(raw)
            capture = BM1.capture
            @test capture(
                () -> BM1.V01.drops(raw, clean),
            ) != ""
            BM1.capture(
                () -> @test !BM1.V01.drops(raw, raw)
            )
            short = clean[2:end, :]
            BM1.capture(
                () -> @test !BM1.V01.golden_n(short)
            )
        end
    end

    @testset "v02 ingest" begin
        out = output("v02", BM1.V02)
        @test occursin(
            "body_mass_g       Union{Missing, Float64}",
            out,
        )
        @test occursin("year              Int64", out)
        @test occursin("\"sex\" => 11", out)
        @test occursin("sex still missing in 9", out)

        @testset "can fail: dropping every column gives 333" begin
            raw = tmp_penguins()
            @test nrow(dropmissing(raw)) == 333
            @test nrow(BM1.AgenticDS.na_policy(raw)) ==
                  342
        end
    end

    @testset "v03 generate" begin
        out = output("v03", BM1.V03)
        @test occursin(
            "Hello, Julia\" == \"Hello, Julia!\"",
            out,
        )
        @test occursin("Fail  Total", out)
        @test occursin("Pass  Total", out)

        @testset "can fail: a non test error is not hidden" begin
            file = scratch_file()
            res = Int[]
            BM1.capture() do
                red = "using Test; @testset \"t\" begin; @test false; end"
                green = "using Test; @testset \"t\" begin; @test true; end"
                push!(res, BM1.runtests(file, red))
                push!(res, BM1.runtests(file, green))
            end
            @test res == [1, 0]
            boom = "error(Char(98))"
            err = try
                BM1.capture(() -> BM1.runtests(file, boom))
            catch e
                e
            end
            @test err isa ErrorException
        end
    end

    @testset "v04 profile" begin
        out = output("v04", BM1.V04)
        @test occursin("Gentoo       123", out)
        @test occursin("504.116", out)
        @test occursin("n = 502.063", out)

        @testset "can fail: the population sd differs" begin
            x = [1.0, 2.0, 4.0]
            @test BM1.V04.sd_by_hand(x, 1) ≈
                  1.5275252316519465
            @test !isapprox(
                BM1.V04.sd_by_hand(x, 1),
                BM1.V04.sd_by_hand(x, 0);
                atol = 1e-3,
            )
            @test BM1.V04.r3(1.23456) == 1.235
        end
    end

    @testset "v05 green" begin
        out = output("v05", BM1.V05)
        @test occursin("AgenticDS P1", out)
        @test occursin("Aqua", out)
        @test occursin("JET", out)

        @testset "can fail: a failing row is not a pass" begin
            nl = Char(10)
            log = join(
                [
                    "Test Summary: | Pass  Fail  Total  Time",
                    "Aqua          |    3     1      4  0.1s",
                    "JET           |          2      2  0.2s",
                    "other         |    1            1  0.0s",
                    "Test Summary: | Pass  Total  Time",
                    "AgenticDS P1  |    5      5  0.3s",
                    "",
                ],
                nl,
            )
            rows = BM1.test_rows(log)
            @test length(rows) == 3
            @test (rows[1].pass, rows[1].total) ==
                  (3, 4)
            @test (rows[2].pass, rows[2].total) ==
                  (0, 2)
            @test (rows[3].pass, rows[3].total) ==
                  (5, 5)
            @test isempty(BM1.test_rows("nothing here"))
        end

        @testset "can fail: a failing inner run is a red verdict" begin
            @test BM1.capture_cmd(
                `sh -c "echo x; exit 3"`,
            ) == "x\n"
            dir = mktempdir()
            mkpath(joinpath(dir, "src"))
            mkpath(joinpath(dir, "test"))
            uuid = "5b6f1a2c-0000-4000-8000-000000000001"
            write(
                joinpath(dir, "Project.toml"),
                "name = \"Scratch\"\nuuid = \"$uuid\"\n" *
                "[extras]\nTest = \"8dfed614-e22c-5e08-85e1-65c5234f0b40\"\n" *
                "[targets]\ntest = [\"Test\"]\n",
            )
            write(
                joinpath(dir, "src", "Scratch.jl"),
                "module Scratch\nend\n",
            )
            write(
                joinpath(dir, "test", "runtests.jl"),
                "using Test\n@testset \"JET\" begin\n" *
                "@test false\nend\n",
            )
            rows = BM1.V05.run_tests(dir)
            @test length(rows) == 1
            @test rows[1].pass < rows[1].total
            red = BM1.capture() do
                ok = all(r -> r.pass == r.total, rows)
                @test !BM1.verdict(ok, "x")
            end
            @test occursin("FAILED", red)
        end
    end

    @testset "v06 json" begin
        out = output("v06", BM1.V06)
        @test occursin(
            "Gentoo    123 [47.5, 3.08, 14.98, 0.98, 217.19," *
            " 6.48, 5076.02, 504.12]",
            out,
        )

        @testset "can fail: a perturbed row misses the golden" begin
            gold = BM1.golden().species.Adelie
            s = BM1.AgenticDS.summarise_by_species(
                BM1.AgenticDS.na_policy(tmp_penguins()),
            )
            r = first(eachrow(s))
            @test isapprox(
                BM1.V06.got(r),
                BM1.V06.want(gold);
                atol = 1e-9,
            )
            bad = BM1.V06.got(r) .+ 0.01
            @test !isapprox(
                bad,
                BM1.V06.want(gold);
                atol = 1e-9,
            )
            @test BM1.V06.r2(1.2345) == 1.23
        end
    end

    # v07 is a shell scene: its commands are run natively by
    # gate/v07.jl, after this package's Pkg.test. Nothing here
    # runs them, so this suite cannot start itself.
    @testset "v07 gates" begin
        m = manifest("v07", "gates")
        n = count(startswith("run"), keys(m))
        cmds = [m["run$i"] for i = 1:n]
        @test n == 3
        @test cmds == BM1.V07.GATES
        @test m["ready"] == "Testing BM1 tests passed"
        @test length(m["ready"]) <= 59
        @test !any(c -> occursin("BM1.V07", c), cmds)
        @test !any(wrapper, cmds)
        @test wrapper(
            "scripts/julia-format.sh julia/BM1",
        )
        @test startswith(
            cmds[2],
            "julia --project=julia/gate -e '",
        )
        @test endswith(cmds[2], "' julia/BM1")
        @test cmds[3] ==
              "julia --project=julia/BM1 -e '" *
              BM1.V07.TEST *
              "'"
    end

    @testset "v08 mutants" begin
        out = output("v08", BM1.V08)
        @test occursin(
            "FAIL na_policy rows == 342",
            out,
        )
        @test occursin("failed: 19", out)
        @test occursin("failed: 12", out)

        @testset "can fail: an unchanged copy survives" begin
            src = read(pathof(BM1.AgenticDS), String)
            same = BM1.capture() do
                @test !BM1.V08.kill(src, "zzzz" => "zzzz")
            end
            @test occursin("failed: 0", same)
            @test isempty(
                BM1.failures(BM1.load_module(src)),
            )
        end
    end

    @testset "v09 parse" begin
        out = output("v09", BM1.V09)
        @test occursin("Float64?", out)
        @test occursin("3800.0", out)

        @testset "can fail: a bad number is missing" begin
            @test ismissing(BM1.V09.num("heavy"))
            @test BM1.V09.num("3800") == 3800.0
        end
    end

    @testset "v10 wrapup" begin
        out = out_lines("v10", BM1.V10)
        @test out[1:2] ==
              fill("contract: ads-julia-p1-v1 OK", 2)

        @testset "can fail: a silent program has no contract" begin
            file = joinpath(mktempdir(), "run.jl")
            write(file, "println(Char(120))\n")
            @test isempty(BM1.contracts(file))
        end
    end
end
