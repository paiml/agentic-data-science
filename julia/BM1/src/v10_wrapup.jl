const EXAMPLES = ["b-m1-p1", "b-m1-p1-profile"]
const DIR =
    joinpath("julia", "AgenticDS.jl", "examples")
const WANT = "contract: ads-julia-p1-v1 OK"
function run_example(name)
    return contracts(joinpath(DIR, name, "run.jl"))
end
function main()
    lines = String[]
    cd(ROOT) do
        for name in EXAMPLES
            append!(lines, run_example(name))
        end
    end
    foreach(println, lines)
    verdict(lines == fill(WANT, 2), "wrap-up")
end
