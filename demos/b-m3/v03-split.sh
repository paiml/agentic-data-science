#!/usr/bin/env bash
# B-M3 video 03-split: red first, then the first tree split (best cut at the midpoint) in a scratch package
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
work="$(mktemp -d)"
trap 'rm -rf -- "${work:?}"' EXIT
cd "$work"
julia -e 'using Pkg; Pkg.generate("Stump")' 2>&1 | grep -v '^\s*$'
mkdir Stump/test
cat > Stump/test/runtests.jl <<'JL'
using Stump, Test
@testset "best_cut" begin
    @test Stump.best_cut([1.0, 2.0, 3.0, 10.0, 11.0, 12.0], [1, 1, 1, 2, 2, 2]) == 6.5
    @test Stump.best_cut([1.0, 2.0, 3.0, 10.0, 11.0, 12.0], [2, 2, 2, 1, 1, 1]) == 6.5
end
JL
echo '--- src/Stump.jl as generated'
cat Stump/src/Stump.jl
echo '--- red: the test is written first'
if julia --project=Stump Stump/test/runtests.jl >"$work/red.log" 2>&1; then echo "red step passed: the test was not red"; exit 1; fi
grep -E 'Test Summary|best_cut|UndefVarError|Error During Test' "$work/red.log" | sed -E 's/ +[0-9.]+m?[0-9.]*s$//; s/ +Time$//; s/ at .*(Stump\/test\/runtests\.jl:[0-9]+)/ at \1/' | head -n 6
cat > Stump/src/Stump.jl <<'JL'
module Stump
gini(counts) = (n = sum(counts); n - sum(abs2, counts) / n)
function best_cut(x, y)
    order = sortperm(x); xs = x[order]; ys = y[order]
    total = [count(==(k), ys) for k in 1:2]; left = zeros(Int, 2)
    best, cut = -Inf, NaN
    for i in 1:(length(xs) - 1)
        left[ys[i]] += 1
        xs[i] == xs[i + 1] && continue
        gain = gini(total) - gini(left) - gini(total .- left)
        gain > best && ((best, cut) = (gain, (xs[i] + xs[i + 1]) / 2))
    end
    return cut
end
end
JL
echo '--- src/Stump.jl implemented: the cut with the biggest drop in n*gini'
cat Stump/src/Stump.jl
echo '--- green'
julia --project=Stump Stump/test/runtests.jl 2>&1 | grep -E 'Test Summary|best_cut' | sed -E 's/ +[0-9.]+m?[0-9.]*s$//; s/ +Time$//'
julia --project=Stump Stump/test/runtests.jl >/dev/null 2>&1
echo "contract: b-m3 a failing best_cut test written first turns green at the midpoint OK"
