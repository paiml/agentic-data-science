const PKG = "julia/BM2"
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
const FORMAT = "$GATEPRJ -e '$FMT' $PKG"
const TEST = "using Pkg; Pkg.test()"
const GATES =
    [FORMAT, "julia --project=$PKG -e '$TEST'"]

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
    ok = all(==(0), codes)
    verdict(ok, "gates exit 0")
    return ok
end
