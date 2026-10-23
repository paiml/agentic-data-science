#!/usr/bin/env bash
# B-M2 video 3: write the failing @testset for closed-form OLS first, then make it green
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
work="/tmp/ads-b-m2-scratch"
rm -rf -- "${work:?}"
mkdir -p "$work"
trap 'rm -rf -- "${work:?}"' EXIT
cd "$work"
julia -e 'using Pkg; Pkg.generate("Scratch")' 2>&1 | grep -v '^\s*$'
mkdir Scratch/test
cat > Scratch/test/runtests.jl <<'JL'
using Scratch, Test
@testset "ols" begin
    b = Scratch.ols([1.0, 2.0, 3.0, 4.0], [3.0, 5.0, 7.0, 9.0])
    @test b.intercept ≈ 1.0
    @test b.slope ≈ 2.0
end
JL
echo '--- red: the test is written first, ols does not exist yet'
if julia --project=Scratch Scratch/test/runtests.jl >"$work/red.log" 2>&1; then echo "red step passed: the test was not red"; exit 1; fi
grep -E 'UndefVarError|Test Summary|Error During|ols' "$work/red.log" | sed -E 's/ +[0-9.]+m?[0-9.]*s$//; s/ +Time$//; s/ at .*(runtests\.jl:[0-9]+)/ at \1/' | head -n 6
cat > Scratch/src/Scratch.jl <<'JL'
module Scratch

"Closed-form simple OLS as the least-squares solution of [1 x] backslash y."
function ols(x, y)
    b = [ones(length(x)) x] \ y
    return (; intercept = b[1], slope = b[2])
end

end # module
JL
echo '--- src/Scratch.jl implemented'
cat Scratch/src/Scratch.jl
echo '--- green'
julia --project=Scratch Scratch/test/runtests.jl 2>&1 | grep -E 'Test Summary|ols' | sed -E 's/ +[0-9.]+m?[0-9.]*s$//; s/ +Time$//'
julia --project=Scratch -e 'using Scratch; b = Scratch.ols([1.0, 2.0, 3.0, 4.0], [3.0, 5.0, 7.0, 9.0]); @assert isapprox(b.intercept, 1.0; atol = 1e-9) && isapprox(b.slope, 2.0; atol = 1e-9)'
echo "contract: b-m2 a failing OLS @testset written first turns green OK"
