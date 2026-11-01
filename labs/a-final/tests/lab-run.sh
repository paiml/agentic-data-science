#!/usr/bin/env bash
# lab-run.sh LABDIR : grade LABDIR (a crate: src/lib.rs + Cargo.toml) against tests/lab_tests.rs (or $LAB_TESTS).
# Exit 0 = every task passes, 1 = a task failed (each named), 2 = could not measure (zero tests never passes).
set -uo pipefail
D=${1:?lab dir (starter or solution)}; D=$(cd "$D" && pwd)
here=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$here/../../.." && pwd)
TESTS=${LAB_TESTS:-$here/lab_tests.rs}
[ -s "$D/src/lib.rs" ] && [ -s "$D/Cargo.toml" ] || { echo "NOT MEASURED: $D/src/lib.rs or Cargo.toml missing"; exit 2; }
[ -s "$TESTS" ] || { echo "NOT MEASURED: $TESTS missing"; exit 2; }
(cd "$REPO/datasets/penguins" && sha256sum -c --quiet SHA256SUMS) >/dev/null 2>&1 || { echo "NOT MEASURED: penguins SHA256SUMS mismatch"; exit 2; }
T=$(mktemp -d); trap 'rm -rf "${T:?}"' EXIT
mkdir -p "$T/lab/tests"; cp -r "$D/src" "$D/Cargo.toml" "$T/lab/"; [ -f "$D/Cargo.lock" ] && cp "$D/Cargo.lock" "$T/lab/"
cp "$TESTS" "$T/lab/tests/lab_tests.rs"
sed -i "s#path = \"../../../rust/ads-rust\"#path = \"$REPO/rust/ads-rust\"#" "$T/lab/Cargo.toml"
# env!(CARGO_MANIFEST_DIR) in the suite points at the temp crate; give it the repo's datasets via a symlink at the same depth.
mkdir -p "$T/a/b"; mv "$T/lab" "$T/a/b/lab"; ln -s "$REPO/datasets" "$T/datasets"
export CARGO_TARGET_DIR=${LAB_TARGET:-/mnt/nvme-raid0/tmp/wkzi-lab-target}
# stubs left in: refuse before running anything.
stub=0; if grep -nE 'todo!\(|unimplemented!\(' "$T/a/b/lab/src/lib.rs" >/dev/null; then stub=1; fi
out=$(cd "$T/a/b/lab" && cargo test --offline --test lab_tests 2>&1); rc=$?
if ! echo "$out" | grep -qE '^test [A-Za-z0-9_]+ \.\.\. '; then
  if echo "$out" | grep -qE 'running 0 tests'; then echo "NOT MEASURED: zero tests ran (a zero-test suite never passes)"; exit 2; fi
  echo "FAIL build (does not compile)"; echo "$out" | grep -E '^error' | head -5; echo "lab: 0 tasks pass"; exit 1
fi
fail=0; n=0
while read -r name res; do
  n=$((n+1)); case "$res" in ok) echo "PASS $name";; *) echo "FAIL $name ($res)"; fail=$((fail+1));; esac
done < <(echo "$out" | sed -n 's/^test \([A-Za-z0-9_]*\) \.\.\. \(.*\)$/\1 \2/p')
if [ "$stub" -eq 1 ]; then echo "FAIL stub (todo!/unimplemented! left in src/lib.rs)"; fail=$((fail+1)); fi
[ "$n" -ge 3 ] || { echo "NOT MEASURED: only $n tests ran, lab needs 3"; exit 2; }
echo "lab: $((n-fail))/$n tasks pass"; [ "$fail" -eq 0 ] && [ "$rc" -eq 0 ] && exit 0 || exit 1
