# Gate for scene v07: run the scene's native commands in a
# shell, exactly as the recorder types them, and check the
# final frame. Run from anywhere by scripts/gate-julia.sh
# after the package's own Pkg.test, so no test recurses.
using Test

const PKG = dirname(@__DIR__)
const ROOT = dirname(dirname(PKG))
const VIEW = 16
module Scene
include(joinpath(@__DIR__, "..", "src", "v07_gates.jl"))
end

function manifest()
    path = joinpath(PKG, "scenes", "v07-gates.scene")
    pairs = map(eachline(path)) do line
        k, v = split(line, " = "; limit = 2)
        return k => v
    end
    return Dict(pairs)
end

# What the recorder types: each command, then its own
# echo "exit=$?". Real capture of stdout and stderr.
function transcript(cmds; dir = ROOT)
    lines = String[]
    for c in cmds
        push!(lines, c)
        push!(lines, "echo \"exit=\$?\"")
    end
    path = tempname()
    sh = Cmd(`bash -c $(join(lines, Char(10)))`; dir)
    open(path, "w") do io
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

function view(text)
    rows = split(rstrip(text), Char(10))
    return join(
        rows[max(1, end - VIEW + 1):end],
        Char(10),
    )
end

m = manifest()
n = count(startswith("run"), keys(m))
cmds = [m["run$i"] for i = 1:n]

@testset "v07 gates" begin
    @testset "manifest is the displayed data" begin
        @test m["shell"] == "1"
        @test !haskey(m, "run")
        @test cmds == Scene.GATES
        @test m["ready"] == "Testing BM1 tests passed"
        @test !any(c -> occursin("BM1.V07", c), cmds)
        @test !any(c -> occursin(".sh", c), cmds)
    end

    @testset "can fail: unformatted code is red" begin
        bad = mktempdir()
        write(joinpath(bad, "Bad.jl"), "f( x )=x+1\n")
        out = transcript([
            replace(Scene.FORMAT, "julia/BM1" => bad),
        ])
        @test occursin("format clean: false", out)
        @test endswith(rstrip(out), "exit=1")
    end

    @testset "can fail: a failing command shows exit=1" begin
        @test endswith(
            rstrip(transcript(["false"])),
            "exit=1",
        )
        @test endswith(
            rstrip(transcript(["true"])),
            "exit=0",
        )
    end

    out = transcript(cmds)
    print(out)
    last_rows = view(out)
    @testset "native run: the final frame" begin
        @test count("exit=0", out) == length(cmds)
        @test occursin("sh:conforms  true", out)
        @test occursin("format clean: true", out)
        @test occursin("Test Summary", last_rows)
        @test occursin(
            r"BM1 suite\s+\|\s+\d+",
            last_rows,
        )
        @test occursin(m["ready"], last_rows)
        @test endswith(rstrip(last_rows), "exit=0")
    end
end
