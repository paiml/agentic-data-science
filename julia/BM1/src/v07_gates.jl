const ALL_EXIT_ZERO = true
const SHACL = "make gate-shacl"
const FMT = join(
    [
        "using JuliaFormatter",
        "ok = format(ARGS[1]; overwrite = false)",
        """println("format clean: ", ok)""",
        "exit(ok ? 0 : 1)",
    ],
    "; ",
)
const GATEPRJ = "julia --project=julia/gate"
const FORMAT = "$GATEPRJ -e '$FMT' julia/BM1"
const TEST = "using Pkg; Pkg.test()"
const PKGTEST = "julia --project=julia/BM1 -e '$TEST'"
# Typed at a shell prompt in the repo root; each one is
# followed by echo "exit=$?".
const GATES = [SHACL, FORMAT, PKGTEST]

# Run each gate in a shell; print its exit code.
function gate(cmd)
    path = tempname()
    code = open(path, "w") do io
        proc = run(
            pipeline(
                ignorestatus(`sh -c $cmd`);
                stdout = io,
                stderr = io,
            ),
        )
        return proc.exitcode
    end
    rm(path)
    return code
end

function main(gates = GATES)
    codes = [gate(g) for g in gates]
    for (i, c) in enumerate(codes)
        println("gate ", i, " exit=", c)
    end
    ok = ALL_EXIT_ZERO && all(==(0), codes)
    verdict(ok, "gates")
    return ok
end
