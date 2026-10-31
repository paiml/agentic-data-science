const TEST = """
@testset "hello" begin
    @test Scratch.hello("Julia") == "Hello, Julia!"
end
"""
const DONE = raw"""
module Scratch
hello(who) = "Hello, $(who)!"
end
"""
function implement(f)
    write(f, DONE)
end
function main()
    ok = cd(mktempdir()) do
        Pkg.generate("Scratch")
        file = "Scratch/src/Scratch.jl"
        write(file, replace(DONE, "!" => ""))
        red = runtests(file, TEST)
        implement(file)
        return red == 1 && runtests(file, TEST) == 0
    end
    verdict(ok, "failing test first, then green")
end
