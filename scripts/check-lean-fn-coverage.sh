#!/usr/bin/env bash
# Lean has no line-coverage tool, so the substitute receipt is: every function and every refusal path
# in the Lean demo and plot code has a test (ads#130, part of #129).
#   FUNCTIONS: every `def` / `abbrev` in lean/AgenticDS/AgenticDS/*.lean must be reachable from a test
#     under lean/AgenticDS/AgenticDSTest/ (named there, or named in the body of a function that is).
#     An untested function is RED. `main` is run by the gate itself and is not counted.
#   REFUSALS: every `throw` and every `none` result in that code, per enclosing function, needs a row in
#     lean/AgenticDS/scripts/refusals.tsv naming the test file and the label the test carries; the
#     file must exist and carry the label. A site with no row is RED, and so is a row with no site.
#   PLOT SCRIPT: every `exit 1|2` and `return 1` in scripts/lean-plot.sh needs a planted arm in
#     scripts/falsify-lean-plot.sh (rows `lean-plot.sh` in refusals.tsv, needle = the arm id).
# usage: check-lean-fn-coverage.sh [--list]     --list prints the function -> test mapping
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
pkg="${LEAN_PKG:-$here/lean/AgenticDS}"
reg="${REFUSALS:-$pkg/scripts/refusals.tsv}"
plot="${LEAN_PLOT:-$here/scripts/lean-plot.sh}"
arms="${LEAN_PLOT_ARMS:-$here/scripts/falsify-lean-plot.sh}"
list=0; [ "${1:-}" = "--list" ] && list=1
fail=0
red() { echo "RED: $*"; fail=1; }
[ -d "$pkg/AgenticDS" ] && [ -d "$pkg/AgenticDSTest" ] || { echo "RED: no Lean package at $pkg"; exit 1; }
[ -s "$reg" ] || { echo "RED: refusal registry $reg missing or empty"; exit 1; }

# One pass over the library: top-level declarations, their comment-free bodies, and the refusal sites.
# Output lines: D<TAB>module<TAB>name | E<TAB>name<TAB>token | S<TAB>module<TAB>name<TAB>kind
lib_scan() {
  awk '
    FNR == 1 { inblk = 0; cur = ""; mod = FILENAME; sub(/.*\//, "", mod); sub(/\.lean$/, "", mod) }
    {
      line = $0
      if (inblk) { if (match(line, /-\//)) { line = substr(line, RSTART + 2); inblk = 0 } else next }
      while (match(line, /\/-/)) {
        pre = substr(line, 1, RSTART - 1); rest = substr(line, RSTART + 2)
        if (match(rest, /-\//)) { line = pre " " substr(rest, RSTART + 2) } else { line = pre; inblk = 1; break }
      }
      sub(/--.*$/, "", line)
      if (line ~ /^(@\[[^]]*\] )?((private|protected|partial|noncomputable|unsafe) )*(def|abbrev) /) {
        s = line; sub(/^(@\[[^]]*\] )?((private|protected|partial|noncomputable|unsafe) )*(def|abbrev) +/, "", s)
        match(s, /^[^ ({\[:]+/); nm = substr(s, RSTART, RLENGTH)
        if (nm == "main") { cur = ""; next }
        cur = nm; print "D\t" mod "\t" nm
      } else if (line ~ /^[A-Za-z@]/ && line !~ /^(namespace|end|open|variable|section|import)/) { cur = "" }
      if (cur == "") next
      if (line ~ /(=>|then|else|return) none([^A-Za-z0-9_]|$)/) print "S\t" mod "\t" cur "\tnone"
      if (line ~ /(^|[^A-Za-z0-9_])throw /) print "S\t" mod "\t" cur "\tthrow"
      n = split(line, tok, /[^A-Za-z0-9_.]+/)
      for (i = 1; i <= n; i++) if (tok[i] != "") print "E\t" cur "\t" tok[i]
    }' "$pkg"/AgenticDS/*.lean
}
# Every identifier a test file names (comments removed the same way).
test_tokens() {
  awk '
    FNR == 1 { inblk = 0 }
    { line = $0
      if (inblk) { if (match(line, /-\//)) { line = substr(line, RSTART + 2); inblk = 0 } else next }
      while (match(line, /\/-/)) { pre = substr(line, 1, RSTART - 1); rest = substr(line, RSTART + 2)
        if (match(rest, /-\//)) { line = pre " " substr(rest, RSTART + 2) } else { line = pre; inblk = 1; break } }
      sub(/--.*$/, "", line)
      n = split(line, tok, /[^A-Za-z0-9_.]+/)
      for (i = 1; i <= n; i++) if (tok[i] != "") print FILENAME "\t" tok[i] }' "$pkg"/AgenticDSTest/*.lean
}

compgen -G "$pkg/AgenticDS/*.lean" >/dev/null || { echo "RED: found no function (no .lean file in $pkg/AgenticDS)"; exit 1; }
scan="$(lib_scan)"; ttok="$(test_tokens)"
ndef="$(printf '%s\n' "$scan" | awk -F'\t' '$1=="D"' | wc -l)"
[ "$ndef" -ge 1 ] || { echo "RED: found no function in $pkg/AgenticDS (a coverage check over nothing is no check)"; exit 1; }

# Closure: a function is tested when a test names it, or when a tested function names it.
res="$( { printf '%s\n' "$scan"; printf '%s\n' "$ttok" | sed 's/^/T\t/'; } | awk -F'\t' '
  function short(n,   k) { k = n; sub(/^.*\./, "", k); return k }
  $1 == "D" { mod[$3] = $2; def[$3] = 1; sh[short($3)] = sh[short($3)] " " $3 }
  $1 == "E" { edge[$2] = edge[$2] " " $3 }
  $1 == "T" { f = $2; sub(/.*\//, "", f); tk = $3
              m = split(tk, parts, "."); for (i = 1; i <= m; i++) seen[parts[i]] = seen[parts[i]] " " f
              seen[tk] = seen[tk] " " f }
  END {
    for (d in def) { k = short(d); how[d] = ""
      if ((d in seen) && !(d ~ /\./)) how[d] = "test:" firstword(seen[d])
      else if (d ~ /\./ && (d in seen)) how[d] = "test:" firstword(seen[d]) }
    # dotted test tokens such as `t.leaves` / `Species.all`: match the short name of a dotted def
    for (t in seen) { n = split(t, p, "."); if (n > 1) for (i = 2; i <= n; i++) sdot[p[i]] = seen[t] }
    for (d in def) if (how[d] == "" && d ~ /\./ && (short(d) in sdot)) how[d] = "test:" firstword(sdot[short(d)])
    do { ch = 0
      for (d in def) if (how[d] != "") {
        n = split(edge[d], e, " ")
        for (i = 1; i <= n; i++) {
          tk = e[i]; cands = ""
          if (tk in def) cands = tk
          m = split(tk, q, "."); for (j = 1; j <= m; j++) if (q[j] in sh) cands = cands sh[q[j]]
          c = split(cands, cc, " ")
          for (j = 1; j <= c; j++) if (cc[j] != d && how[cc[j]] == "") { how[cc[j]] = "via:" d; ch = 1 }
        } }
    } while (ch)
    for (d in def) print mod[d] "\t" d "\t" (how[d] == "" ? "UNTESTED" : how[d])
  }
  function firstword(s,   a) { split(s, a, " "); return a[1] }' | sort)"

untested="$(printf '%s\n' "$res" | awk -F'\t' '$3=="UNTESTED"')"
if [ -n "$untested" ]; then
  printf '%s\n' "$untested" | while IFS="$(printf '\t')" read -r m n _; do
    echo "RED: function $m.$n has no test (no test under AgenticDSTest names it, nor a tested function that calls it)"; done
  fail=1
fi
tested=$(( ndef - $(printf '%s\n' "$untested" | grep -c . || true) ))
echo "functions: $tested of $ndef reachable from a test"
if [ "$list" -eq 1 ]; then printf '%s\n' "$res" | awk -F'\t' '{ printf "  %-12s %-18s %s\n", $1, $2, $3 }'; fi

# Refusal sites in the library, per enclosing function.
sites="$(printf '%s\n' "$scan" | awk -F'\t' '$1=="S" { print $2 "\t" $3 "\t" $4 }' | sort -u)"
rows="$(awk -F'\t' '!/^#/ && NF >= 5 && $1 != "lean-plot.sh"' "$reg")"
unreg="$(printf '%s\n' "$sites" | while IFS="$(printf '\t')" read -r m n k; do
  [ -n "$m" ] || continue
  printf '%s\n' "$rows" | awk -F'\t' -v m="$m" -v n="$n" -v k="$k" '$1==m && $2==n && $3==k { f=1 } END { exit !f }' \
    || echo "RED: refusal path $m.$n ($k) has no row in refusals.tsv (and so no test)"
done)"
if [ -n "$unreg" ]; then printf '%s\n' "$unreg"; fail=1; fi
nrows=0
while IFS="$(printf '\t')" read -r m n k tf needle; do
  [ -n "$m" ] || continue; nrows=$((nrows + 1))
  printf '%s\n' "$sites" | awk -F'\t' -v m="$m" -v n="$n" -v k="$k" '$1==m && $2==n && $3==k { f=1 } END { exit !f }' \
    || { red "registry row $m $n $k names no refusal site in the library (stale row)"; continue; }
  tfp="$pkg/$tf"; [ -f "$tfp" ] || tfp="$here/$tf"
  [ -f "$tfp" ] || { red "refusal $m.$n ($k): test file $tf does not exist"; continue; }
  grep -qF -- "$needle" "$tfp" || red "refusal $m.$n ($k): $tf does not carry the label '$needle'"
done <<EOF
$rows
EOF
nsites="$(printf '%s\n' "$sites" | grep -c . || true)"
echo "refusal paths (library): $nsites sites, $nrows registry rows"

# lean-plot.sh: every refusal exit needs a planted arm.
[ -f "$plot" ] && [ -f "$arms" ] || { echo "RED: $plot or $arms missing"; exit 1; }
pexits="$(grep -cE 'exit [12]|return 1' "$plot" || true)"
prows="$(awk -F'\t' '!/^#/ && $1 == "lean-plot.sh" && NF >= 4' "$reg")"
np="$(printf '%s\n' "$prows" | grep -c . || true)"
[ "$pexits" -eq "$np" ] || red "lean-plot.sh has $pexits refusal exits but refusals.tsv has $np rows for it"
while IFS="$(printf '\t')" read -r _ marker tf needle; do
  [ -n "$marker" ] || continue
  grep -qF -- "$marker" "$plot" || red "lean-plot.sh: no refusal carries '$marker' (stale row)"
  grep -qF -- "$needle" "$arms" || red "lean-plot.sh refusal '$marker': $tf has no arm '$needle'"
done <<EOF
$prows
EOF
echo "plot refusals (lean-plot.sh): $pexits exits, $np planted-arm rows"
if [ "$fail" -eq 0 ]; then echo "lean fn coverage OK"; else exit 1; fi
