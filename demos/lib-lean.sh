#!/usr/bin/env bash
# Shared setup for Lean terminal demos: every tool runs natively in the Lean package, then `echo "exit=$?"` shows its real status.
export PATH="$HOME/.elan/bin:$PATH"
ADS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ADS_ROOT
cd "$ADS_ROOT/lean/AgenticDS" || exit 1
