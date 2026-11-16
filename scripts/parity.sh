#!/usr/bin/env bash
# Cross-language parity (ADS-DEMO-001 R-4).
# usage: parity.sh <dir with <lang>/stdout.txt> <landed-file>
# Every language named in <landed-file> MUST have a non-empty stdout.txt and match the first byte for byte;
# a missing one is RED, never skipped. The course languages not yet landed are printed as NOT RUN.
set -euo pipefail
d="$1"; landed="$2"; ref=""; n=0; all="rust julia r kotlin lean"
[ -s "$landed" ] || { echo "FAIL: no landed-languages file $landed"; exit 1; }
while read -r lang; do
  [ -n "$lang" ] || continue
  case " $all " in *" $lang "*) ;; *) echo "FAIL: unknown language $lang"; exit 1;; esac
  f="$d/$lang/stdout.txt"
  [ -s "$f" ] || { echo "FAIL: landed language $lang has no stdout.txt ($f)"; exit 1; }
  h=$(sha256sum "$f" | cut -d' ' -f1); n=$((n+1))
  if [ -z "$ref" ]; then ref="$h"; first="$f"
  elif [ "$h" != "$ref" ]; then echo "FAIL parity: $f differs from $first"; diff "$first" "$f" || true; exit 1; fi
done < "$landed"
[ "$n" -ge 1 ] || { echo "FAIL: no languages landed"; exit 1; }
pend=""; for l in $all; do /usr/bin/grep -qx "$l" "$landed" || pend="$pend $l"; done
echo "parity OK: $n language(s); NOT RUN (pending):${pend:- none}"
