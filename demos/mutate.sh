#!/usr/bin/env bash
# Scratch-copy mutation helper for demos: mutate <file under julia/AgenticDS.jl/src> <sed expr>
# Prints the failing tests; returns 0 when the mutant is killed (>=1 failure, 0 errors).
mutate() {
  local file="$1" expr="$2" sc log failed errored
  sc="$(mktemp -d)"
  mkdir -p "$sc/julia"
  cp -r "$ADS_ROOT/julia/AgenticDS.jl" "$sc/julia/AgenticDS.jl"
  cp -r "$ADS_ROOT/datasets" "$sc/datasets"
  sed -i "$expr" "$sc/julia/AgenticDS.jl/src/$file"
  if cmp -s "$ADS_ROOT/julia/AgenticDS.jl/src/$file" "$sc/julia/AgenticDS.jl/src/$file"; then echo "mutation did not change src/$file"; rm -rf -- "${sc:?}"; return 1; fi
  echo "mutation in src/$file: sed '$expr'"
  diff "$ADS_ROOT/julia/AgenticDS.jl/src/$file" "$sc/julia/AgenticDS.jl/src/$file" | grep '^[<>]' || true
  log="$sc/test.log"
  julia --project="$sc/julia/AgenticDS.jl" -e 'using Pkg; Pkg.test()' >"$log" 2>&1 || true
  grep 'Test Failed at' "$log" | sed -E 's/\x1b\[[0-9;]*m//g' | sed -E 's/^(.*): Test Failed at .*\/test\/([a-z0-9]+\.jl:[0-9]+)$/FAIL \1 (\2)/' | head -n 8
  failed="$(grep -c 'Test Failed at' "$log" || true)"
  errored="$(grep -c 'Error During Test' "$log" || true)"
  echo "failed: $failed  errored: $errored"
  rm -rf -- "${sc:?}"
  [ "$failed" -gt 0 ] && [ "$errored" -eq 0 ]
}
