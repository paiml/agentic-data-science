# Grader-owned runner. It runs in a process where NO learner code is ever loaded: the learner's package lives in a
# child process (serve.jl) and answers over a socket with values only (wire.jl). The tests are included here, so the
# counts are computed here, from this process's own testset results. grade.sh pipes "<result path>\t<nonce>" on stdin.
# usage: julia --project=<grader shim project> run.jl <runtests.jl> <learner tree> <serve.jl> <wire.jl>
using Test, Sockets, JSON3

const RESULT, NONCE = String.(split(readline(stdin), '\t'))
const TESTS, LEARNER, SERVE, WIRE = ARGS

import AgenticDS
const server = listen(ip"127.0.0.1", 0)
const port = Int(getsockname(server)[2])
const child = run(pipeline(Cmd(`$(Base.julia_cmd()) --project=. $SERVE $port $WIRE`; dir = LEARNER);
    stdin = devnull, stdout = stderr, stderr = stderr); wait = false)
const sock = Ref{Any}(nothing)
let t = Timer(_ -> close(server), 120)   # a child that never connects (crash, infinite loop) is a failed run
    try sock[] = accept(server) catch; end
    close(t)
end
AgenticDS.RPC[] = function (name, arg)
    sock[] === nothing && error("the learner process never connected")
    println(sock[], JSON3.write(Dict("f" => name, "arg" => arg)))
    line = readline(sock[])
    isempty(line) && error("the learner process closed the connection (exited or crashed)")
    return JSON3.read(line)
end

function tally()
    try
        ts = include(TESTS)
        c = Test.get_test_counts(ts)
        return (c.passes + c.cumulative_passes, c.fails + c.cumulative_fails, c.errors + c.cumulative_errors)
    catch e
        e isa LoadError && (e = e.error)  # include wraps the testset failure
        e isa Test.TestSetException && return (e.pass, e.fail, e.error)
        showerror(stderr, e)
        return (0, 0, 1)
    end
end

const (p, f, e) = tally()
try sock[] === nothing || close(sock[]) catch; end   # EOF ends the child cleanly
let t0 = time()
    while process_running(child) && time() - t0 < 10; sleep(0.1); end
    process_running(child) && kill(child, Base.SIGKILL)
end
write(RESULT, "$NONCE pass=$p fail=$f error=$e\n")
exit(f + e == 0 ? 0 : 1)
