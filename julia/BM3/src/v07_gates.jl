# The gates every package passes before a merge.
# Typed at a shell prompt, each exits 0.
const PKG = "julia --project=julia/BM3"
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
const FORMAT = "$GATEPRJ -e '$FMT' julia/BM3"
const TEST = "$PKG -e 'using Pkg; Pkg.test()'"
const GATES = [FORMAT, TEST]
