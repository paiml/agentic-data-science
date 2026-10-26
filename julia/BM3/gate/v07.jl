# Runs the commands of scene v07 exactly as the recorder types
# them at a shell prompt: each runN line, then a separate
# echo "exit=$?". Run after the package's own Pkg.test, from
# anywhere: julia julia/BM3/gate/v07.jl
# Nothing is filtered: the output is captured whole, and the
# last 16 rows (the viewport) must hold the evidence.
using Test

const PKG = normpath(joinpath(@__DIR__, ".."))
const ROOT = normpath(joinpath(PKG, "..", ".."))
const VIEWPORT = 16

function manifest(path)
    pairs = split.(readlines(path), " = "; limit = 2)
    return Dict(
        String(k) => String(v) for (k, v) in pairs
    )
end

function commands(keys)
    runs = String[]
    while haskey(keys, "run$(length(runs) + 1)")
        push!(runs, keys["run$(length(runs) + 1)"])
    end
    return runs
end

# One command as typed, then the separate echo; both streams.
function typed(cmd)
    script =
        string(cmd, "\n", "echo \"exit=\$?\"", "\n")
    path = tempname()
    open(path, "w") do io
        sh = Cmd(`sh -c $script`; dir = ROOT)
        run(
            pipeline(
                ignorestatus(sh);
                stdout = io,
                stderr = io,
            ),
        )
    end
    return read(path, String)
end

rows(out) = split(chomp(out), "\n")
frame(out) = join(last(rows(out), VIEWPORT), "\n")

function final_ok(out, ready, summary)
    f = frame(out)
    return occursin(summary, f) &&
           occursin(ready, f) &&
           endswith(strip(out), "exit=0")
end

keys =
    manifest(joinpath(PKG, "scenes", "v07-gates.scene"))
shown = Module()
Base.include(shown, joinpath(PKG, keys["file"]))

@testset "v07 gates" begin
    runs = commands(keys)
    @test keys["shell"] == "1"
    @test runs == shown.GATES
    @test !any(c -> occursin(".sh", c), runs)
    @testset "can fail: unformatted code is red" begin
        bad = mktempdir()
        write(joinpath(bad, "Bad.jl"), "f( x )=x+1\n")
        out =
            typed(replace(runs[1], "julia/BM3" => bad))
        @test occursin("format clean: false", out)
        @test endswith(strip(out), "exit=1")
        @test occursin(
            "format clean: true",
            typed(runs[1]),
        )
    end
    @testset "can fail: the frame check rejects" begin
        sum = "Test Summary"
        pass = "Testing BM3 tests passed"
        good = "$sum\nBM3 suite\n$pass\nexit=0\n"
        @test final_ok(good, pass, sum)
        @test !final_ok(
            replace(good, sum => ""),
            pass,
            sum,
        )
        @test !final_ok(
            replace(good, pass => ""),
            pass,
            sum,
        )
        @test !final_ok(
            replace(good, "exit=0" => "exit=1"),
            pass,
            sum,
        )
        @test !final_ok(
            good * "x\n"^VIEWPORT * "exit=0",
            pass,
            sum,
        )
        out = typed("(exit 3)")
        @test endswith(strip(out), "exit=3")
        @test !final_ok(
            typed("echo $sum $pass; false"),
            pass,
            sum,
        )
    end
    outs = String[]
    for cmd in runs
        out = typed(cmd)
        push!(outs, out)
        println(out)
        @test endswith(strip(out), "exit=0")
    end
    out = last(outs)
    println(frame(out))
    summary = "Test Summary"
    @test final_ok(out, keys["ready"], summary)
    @test occursin("BM3 suite", frame(out))
end
