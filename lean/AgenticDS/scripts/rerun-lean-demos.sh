#!/usr/bin/env bash
# rerun-lean-demos.sh N BIN_DIR ID...   (ID = m<M>v<NN>, e.g. m2v05; run from lean/AgenticDS)
# Runs each demo N times, serially. A run counts only if it exits 0, its stdout is NOT empty, and its stdout
# and plot (plot-*.svg) sha256 equal the first run's. An empty stdout is a failure (ads#132): a demo that
# prints nothing proves nothing. A demo listed in scripts/contract-demos.txt must also end in a
# `contract: ... OK` line. Prints `ID N/total`; exit 1 unless every demo is total/total.
set -uo pipefail
N=${1:?N}; BIN=${2:?BIN_DIR}; shift 2
LIST=${CONTRACT_LIST:-scripts/contract-demos.txt}
T=$(mktemp -d); trap 'rm -rf "${T:?}"' EXIT
bad=0
for id in "$@"; do
  m=${id#m}; m=${m%%v*}; v=v${id##*v}
  first=""; ok=0; why=""
  for i in $(seq 1 "$N"); do
    rm -f plot-*.svg
    "$BIN/example-m$m" "$v" >"$T/out" 2>"$T/err"; rc=$?
    sig="$(sha256sum <"$T/out")/$(ls plot-*.svg 2>/dev/null | sort | xargs -r sha256sum | awk '{print $1}' | sha256sum)"
    [ "$i" -eq 1 ] && first=$sig
    if [ "$rc" -ne 0 ]; then why="exit $rc"; continue; fi
    if [ ! -s "$T/out" ]; then why="empty stdout"; continue; fi
    if grep -qx "$id" "$LIST" 2>/dev/null && ! tail -n 1 "$T/out" | grep -Eq '^contract: .* OK$'; then why="no contract line"; continue; fi
    if [ "$sig" != "$first" ]; then why="differs from run 1"; continue; fi
    ok=$((ok+1))
  done
  rm -f plot-*.svg
  echo "$id $ok/$N${why:+ ($why)}"
  [ "$ok" -eq "$N" ] || bad=1
done
exit "$bad"
