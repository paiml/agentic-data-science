#!/usr/bin/env bash
# B-M1 video 3: Pkg.generate a package, write the failing @testset first, then make it green
# shellcheck source=../lib-julia.sh
source "$(dirname "$0")/../lib-julia.sh"
work="/tmp/ads-b-m1-scratch"
rm -rf -- "${work:?}"
mkdir -p "$work"
trap 'rm -rf -- "${work:?}"' EXIT
cd "$work"
julia -e 'using Pkg; Pkg.generate("Scratch")' 2>&1 | grep -v '^\s*$'
mkdir Scratch/test
cat > Scratch/test/runtests.jl <<'JL'
using Scratch, Test
@testset "greet" begin
    @test Scratch.greet() == "Hello, Julia"
end
JL
echo '--- src/Scratch.jl as generated'
cat Scratch/src/Scratch.jl
echo '--- red: the test is written first'
if julia --project=Scratch Scratch/test/runtests.jl >"$work/red.log" 2>&1; then echo "red step passed: the test was not red"; exit 1; fi
echo
grep -E 'Test Failed|Expression|Evaluated|Test Summary|greet' "$work/red.log" | sed -E 's/ +[0-9.]+m?[0-9.]*s$//; s/ +Time$//; s/^Hello World!//; s/ at .*\/(Scratch\/test\/runtests\.jl:[0-9]+)/ at \1/'
sed -i 's/Hello World!/Hello, Julia/;s/greet() = print(\(.*\))/greet() = \1/' Scratch/src/Scratch.jl
echo '--- src/Scratch.jl implemented'
cat Scratch/src/Scratch.jl
echo '--- green'
julia --project=Scratch Scratch/test/runtests.jl 2>&1 | grep -E 'Test Summary|greet' | sed -E 's/ +[0-9.]+m?[0-9.]*s$//; s/ +Time$//'
echo "contract: b-m1 a failing @testset written first turns green OK"
