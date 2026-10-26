# Gate for scene v07: runs the scene's own shell commands, live
# from the repo root, and checks the final frame. It runs after
# the package's Pkg.test (scripts/gate-julia.sh), never inside it.
# Usage: julia julia/BM2/gate/v07.jl   (from the repo root)
using Test

const ROOT =
    abspath(joinpath(@__DIR__, "..", "..", ".."))
const ROWS = 16
const PKG = "julia/BM2"
module Scene
include(joinpath(@__DIR__, "..", "src", "v07_gate.jl"))
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

"Type `cmd` at a shell, then a separate echo of its exit."
function typed(cmd; dir = ROOT)
    script = "$cmd\necho \"exit=\$?\"\n"
    path, io = mktemp()
    run(
        pipeline(
            Cmd(`bash -c $script`; dir);
            stdout = io,
            stderr = io,
        ),
    )
    close(io)
    return readlines(path)
end

"The last `ROWS` rows are the final frame."
frame(lines) = lines[max(1, end - ROWS + 1):end]

"Final frame holds the summary, the pass line, exit=0."
function final_ok(lines)
    f = join(frame(lines), "\n")
    return occursin("Test Summary", f) &&
           occursin("Testing BM2 tests passed", f) &&
           lines[end] == "exit=0"
end

@testset "v07 gate (native commands)" begin
    scene = manifest(
        joinpath(
            ROOT,
            "julia/BM2/scenes/v07-gate.scene",
        ),
    )
    @test scene["shell"] == "1"
    runs =
        [scene["run$i"] for i = 1:length(Scene.GATES)]
    @test runs == Scene.GATES
    @test !haskey(scene, "run$(length(runs) + 1)")

    fmt = typed(runs[1])
    @test "format clean: true" in fmt
    @test fmt[end] == "exit=0"

    test = typed(runs[2])
    @test final_ok(test)
    @test count(startswith("exit="), test) == 1

    # can fail: a badly formatted package turns the format red
    bad = mktempdir()
    write(joinpath(bad, "Bad.jl"), "f( x )=x+1\n")
    red = typed(replace(runs[1], PKG => bad))
    @test "format clean: false" in red
    @test red[end] == "exit=1"
    # can fail: a nonzero exit is shown as it is
    @test typed("false")[end] == "exit=1"
    # can fail: a frame without the summary, the pass line or
    # exit=0 is rejected; so is a summary pushed out of the frame
    ok = [
        "Test Summary: | Pass",
        "Testing BM2 tests passed",
        "exit=0",
    ]
    @test final_ok(ok)
    @test !final_ok(ok[2:3])
    @test !final_ok([ok[1]; ok[3]])
    @test !final_ok([ok[1:2]; "exit=1"])
    @test !final_ok([ok[1]; fill("x", ROWS); ok[2:3]])
end
