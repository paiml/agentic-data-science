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
