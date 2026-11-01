# Grader-owned runner (lives in /grader, never in the learner's tree). grade.sh pipes "<result path>\t<nonce>" on stdin;
# nothing secret is in the environment or argv. It includes the grader's runtests.jl, then writes the counts to the
# result file. The learner's code runs in this same process, so stdout and the exit code are not evidence: only the
# result file is. A run that never reaches the write below (exit(0) from learner code, a crash) leaves no file = FAIL.
using Test

const RESULT, NONCE = String.(split(readline(stdin), '\t'))
const TESTS = ARGS[1]

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
write(RESULT, "$NONCE pass=$p fail=$f error=$e\n")
exit(f + e == 0 ? 0 : 1)
