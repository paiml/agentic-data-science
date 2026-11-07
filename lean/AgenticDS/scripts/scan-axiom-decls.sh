#!/usr/bin/env bash
# Refuse any `axiom` declaration in Lean sources (D50 1c). Usage: scan-axiom-decls.sh DIR... ; exit 1 and print hits if found.
set -uo pipefail
hits=$(grep -rn --include=*.lean --include=*.lean.planted -E '^[[:space:]]*(@\[[^]]*\][[:space:]]*)?((private|protected|unsafe)[[:space:]]+)*axiom[[:space:]]' "$@" 2>/dev/null)
[ -z "$hits" ] || { echo "$hits"; exit 1; }
