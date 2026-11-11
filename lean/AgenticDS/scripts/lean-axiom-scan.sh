#!/usr/bin/env bash
# Refuse a user-declared `axiom` in Lean sources (c05 2.3.0: "user-declared axioms are what's banned").
# #print axioms (gate-lean.sh) only checks listed theorems; this closes the unlisted-declaration gap.
# Usage: scripts/lean-axiom-scan.sh PATH...   exit 0 clean, 1 on a declaration (matches printed), 2 on a missing path.
set -uo pipefail
PAT='^[[:space:]]*(@\[[^]]*\][[:space:]]*)?((private|protected|unsafe|noncomputable|partial)[[:space:]]+)*axiom([[:space:]]|$)'
for p in "$@"; do [ -e "$p" ] || { echo "FAIL missing path: $p" >&2; exit 2; }; done
if grep -rnE --include='*.lean' --include='*.lean.planted' "$PAT" "$@"; then exit 1; fi
exit 0
