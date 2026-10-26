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
