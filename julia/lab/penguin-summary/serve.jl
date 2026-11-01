# Runs in the CHILD process, which loads the learner's package. Answers the grader's calls with values only.
# usage: julia --project=<learner tree> serve.jl <port> <wire.jl>
using Sockets, JSON3
include(ARGS[2])
const sock = connect(ip"127.0.0.1", parse(Int, ARGS[1]))
using AgenticDS
const F = Dict(
    "read_penguins" => (a -> AgenticDS.read_penguins(String(a.str))),
    "na_policy" => (a -> AgenticDS.na_policy(Wire.decode(a.df))),
    "summarise_by_species" => (a -> AgenticDS.summarise_by_species(Wire.decode(a.df))),
    "summary_json" => (a -> AgenticDS.summary_json(Wire.decode(a.df))),
)
for line in eachline(sock)
    req = JSON3.read(line)
    reply = try
        Wire.packarg(F[String(req.f)](req.arg))
    catch e
        Dict("err" => first(sprint(showerror, e), 400))
    end
    println(sock, JSON3.write(reply))
end
