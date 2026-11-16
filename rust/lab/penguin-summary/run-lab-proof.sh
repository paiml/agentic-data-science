#!/usr/bin/env bash
# Runs the lab's one test suite on the starter and on the solution and prints both exit codes.
# Proof = starter exits non-zero (and names failing tests), solution exits 0, test files byte-identical.
# MUTANTS=1 also runs two broken solutions (must both fail). Needs cargo (Rust stable) and a populated or network-reachable cargo registry.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
export CARGO_TARGET_DIR=${CARGO_TARGET_DIR:-$(mktemp -d)}
cmp -s "$here/starter/tests/lab.rs" "$here/solution/tests/lab.rs" || { echo "REFUSED: test files differ"; exit 2; }
cmp -s "$here/starter/Cargo.toml" "$here/solution/Cargo.toml" || { echo "REFUSED: manifests differ"; exit 2; }
runrc() { ( cd "$1" && CARGO_TARGET_DIR="$CARGO_TARGET_DIR/$(basename "$1")" cargo test --color never </dev/null > "$2" 2>&1 ); }
for v in starter solution; do
  runrc "$here/$v" "$here/run-$v.log"; rc=$?
  echo "$v exit=$rc | $(grep -E '^test result' "$here/run-$v.log" | tr '\n' ' ')"
  eval "rc_$v=$rc"
done
ok=1
if [ "${MUTANTS:-0}" = 1 ]; then
  t=$(mktemp -d)
  mk() { cp -r "$here/solution" "$t/$1"; sed -i "$2" "$t/$1/src/lib.rs"; }
  mk popsd 's/col(m).std(1)/col(m).std(0)/'
  mk dropnull 's/\.and(col(\*m).is_not_null())/.and(lit(true))/'
  for m in popsd dropnull; do
    cmp -s "$t/$m/src/lib.rs" "$here/solution/src/lib.rs" && { echo "mutant $m: sed changed nothing, REFUSED"; ok=0; continue; }
    runrc "$t/$m" "$here/run-mutant-$m.log"; rc=$?
    echo "mutant $m exit=$rc | $(grep -E "^test result" "$here/run-mutant-$m.log" | tr '\n' ' ')"
    [ "$rc" -ne 0 ] || ok=0
  done
fi
sed -i -E "s@(/[A-Za-z0-9._-]+)*/(\.cargo/registry|\.rustup|targets|tmp)[^ :)]*@<path>@g; s@/mnt/[^ :)]*@<path>@g; s@/home/[^ :)]*@<path>@g" "$here"/run-*.log
[ "$rc_starter" -ne 0 ] && [ "$rc_solution" -eq 0 ] && [ "$ok" = 1 ] && { echo "PROOF OK: starter fails, solution passes"; exit 0; }
echo "PROOF FAILED"; exit 1
