#!/usr/bin/env bash
# gen-demos.sh M: write demos/a-mM/v01..v10 for module M (Rust course). Each runs one command and
# ends on `contract: a-mM vKK <name> OK`, reached only if the command succeeded (set -e).
set -euo pipefail
cd "$(dirname "$0")/.."
m="${1:?module 1-4}"
case $m in
  1) e1=a-m1-p1; e2=a-m1-p1-profile; t=p1; fx='head -4 datasets/penguins/penguins.csv';;
  2) e1=a-m2-p2-ols; e2=a-m2-p2-cv; t=p2; fx='head -6 datasets/fixtures/folds.csv';;
  3) e1=a-m3-p3-tree; e2=a-m3-p3-kmeans; t=p3; fx='head -4 datasets/fixtures/centroids.csv';;
  4) e1=a-m4-p4-pipeline; e2=a-m4-p4-bench; t=p4; fx='head -3 datasets/wine-quality/winequality-red.csv';;
  *) echo "module 1-4" >&2; exit 2;;
esac
EX="cargo run -q --locked --manifest-path rust/ads-rust/Cargo.toml --example"
mkdir -p "demos/a-m$m"
w() { # idx name title command
  local f="demos/a-m$m/v$1-$2.sh"
  printf '%s\n' '#!/usr/bin/env bash' "# A-M$m video ${1#0}: $3" '# shellcheck source=../lib-rust.sh' \
    'source "$(dirname "$0")/../lib-rust.sh"' "$4" "echo \"contract: a-m$m v$1 $2 OK\"" > "$f"
  chmod +x "$f"
}
w 01 example-one "run $e1" "$EX $e1"
w 02 example-two "run $e2" "$EX $e2"
w 03 unit-tests "the $t tests, golden parity and mutants" "cargo test --locked --manifest-path rust/ads-rust/Cargo.toml --test $t"
w 04 golden-json "the committed golden file" "out=\$(jq . datasets/golden/$t.json); head -28 <<<\"\$out\""
w 05 contract-yaml "the provable contract for $t" "head -28 contracts/ads-rust-$t-v1.yaml"
w 06 fixture "the fixture the run reads" "$fx"
w 07 shacl "make gate-shacl" "make gate-shacl"
w 08 pmat "make gate-pmat" "make gate-pmat"
w 09 rust-gate "make gate-rust" "make gate-rust"
w 10 full-gate "the Rust course gates in order" "make gate-datasets gate-shacl gate-rust gate-pmat"
