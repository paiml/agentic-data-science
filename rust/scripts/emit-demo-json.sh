#!/usr/bin/env bash
# emit-demo-json.sh OUT.json: one demo row per rust/term-demos/<id>.cmds, in the same row shape as the Lean emitter
# (lean/AgenticDS/scripts/emit-term-demos.sh): {id:"term-<file stem>", command, commands[], exit, stdout, stdout_sha256, plots:[]}.
#
# INPUT: a row is two files. <id>.cmds holds the lines a terminal session types, one per Enter, and nothing else; <id>.cwd
# (one line, relative to the repository root) is where the session starts. The id is the opaque file stem, [a-z0-9]+.
# term-demos/env holds the fixed session environment (KEY=VALUE lines).
# term-demos/rows.list pins the rows, one line each: "<id> <sha256 of <id>.cmds> <sha256 of <id>.cwd>" (# comments allowed).
# A row file that is not listed, a listed file that is missing, and a file whose sha256 differs from its pin are refused.
#
# CLOSED COMMAND FORM (an allow-list; every line of every .cmds is checked before anything runs): a line is words joined
# by single spaces, with no leading or trailing space; it is not empty; every byte is in the alphabet
#   A-Z a-z 0-9 _ . / : = , + -
# (spelled out in ALPHABET below, so no range and no collation); the first word holds no "=" and is one of FIRST_WORDS.
# Anything else is refused (E-FORM <file>:<line> <reason>). So a line holds no quote, expansion, escape, operator,
# redirection, glob, comment, tab or newline: the shell has nothing to interpret, and the words are the argv.
#
# EXECUTION (the unit is one typed line): every file runs in ONE bash under a 93x25 pty (util-linux `script`). Each line is
# shown as an interactive shell shows it ("$ " first), split on its single spaces and run as that argv: no eval, no join.
# A line whose status is non-zero ends the session at that line. An EXIT trap writes "<line> <status>" (or "end 0") to a
# status file outside the pty; that record, not the transcript, gives the row's `exit` and the line that failed. No row
# may expect a non-zero status.
#
# LOCALE: LC_ALL=C and TZ=UTC are set at the top of this script (file order), the id check spells its set out (no
# range, so no collation), and LC_ALL=C, TZ=UTC are forced into every row's
# environment; term-demos/env may not set them (nor any other key the emitter owns).
# GIT: every git this script runs, and every git a row runs, reads no system and no global config file
# (GIT_CONFIG_NOSYSTEM=1, GIT_CONFIG_GLOBAL=/dev/null); a row's git trusts the repository root by command-line config only.
#
# NORMALISATION (stdout is the pty transcript; ANSI and CR are stripped first), in this order:
#   N1 the two known absolute roots are replaced everywhere, longest first, in logical and physical spelling:
#      the cargo target dir -> "target", the repository root -> ".". (CARGO_TARGET_DIR defaults to rust/ads-rust/target
#      and is exported to every row, so every cargo build in a row writes under that one known root.)
#   N2 cargo progress lines are dropped: a line that is only cargo's status form, a verb right-aligned in 12 columns
#      (Compiling, Checking, Fresh, Downloading, Downloaded, Blocking, Updating, Locking, Adding, Unpacking) then a space.
#      Their presence depends on the build cache, not on the lesson. Every other line is kept: `warning:`, `error...`,
#      `Finished`, `Running`.
#   N3 a closed list of token rules: `-<16 hex>` at the end of a path under "target/" -> `-0000000000000000`;
#      ` in N.NNs` -> ` in 0.00s`; `commit=<40 hex>` -> `commit=` + 40 zeros; a measured `polars: N ms` / `btreemap: N ms`
#      line -> 0.000000 ms.
#   N4 REFUSAL scan: a row whose normalised transcript still holds an absolute path under a host prefix (/home/, /tmp/,
#      /root/, /Users/, /runner/, /github/, /__w/, /var/folders/, /private/ and the mount root), the caller's HOME, CARGO_HOME,
#      RUSTUP_HOME, TMPDIR or the emitter's work dir, or any run of 16 or more hex digits other than exactly 16 zeros or
#      exactly 40 zeros (the tokenised values), is refused, naming the row and the transcript line. The one exemption is a
#      WHOLE decimal literal: [+-]D.digits[e|E[+-]E], D at most 15 digits, E at most 3, whose neighbours are line edge or
#      not [A-Za-z0-9_.+-]. So no 16-digit run hides in its integer part or its exponent, and a literal glued into a longer
#      token (pkg-1.0123456789012345-rc1) stays scanned. A trailing slash on CARGO_TARGET_DIR is dropped
#      before N1. A case N1..N3 misses is a red, never a silent leak.
#
# GUARDS (fail closed: no OUT is written, a stale OUT is removed first). Each refusal names its error id:
#   E-TOOL a tool is missing; E-INPUT no .cmds files; E-ID an id that is not [a-z0-9]+; E-ROWS the row files and the pins
#   in term-demos/rows.list disagree, or the emitted count differs from the declared one; E-EMPTY a .cmds with no command
#   line; E-FORM a line outside the closed command form (file:line reason); E-CWD a .cwd that is not a directory under the
#   root; E-ENV term-demos/env sets an emitter-owned key; E-WARM the warm-up build failed; E-STATUS a line exited non-zero
#   (row, line, status; 126/127 = not runnable); E-TIMEOUT the session ran past TERM_DEMO_TIMEOUT_S; E-NOSTATUS no end
#   record (the session was killed, or ended before its last line); E-TRANSCRIPT the transcript does not show every
#   command; E-TESTS a session that runs `cargo test` shows no `test result:` line, a failed or ignored test, or
#   passed == 0; E-LEAK the refusal scan (N4). The falsifier has one passing refusal arm for every id in this file.
# A refused row prints the last 20 normalised transcript lines to stderr.
# The file carries the commit; CI attests it with actions/attest-build-provenance.
# ENV: ADS_ROOT (repo root), ADS_TERM_DIR (default rust/term-demos), ADS_WARM (command run first, in the crate dir, its
# output not recorded: builds the crate so a recorded session shows no compile lines), TERM_DEMO_TIMEOUT_S (2400).
# PATH, CARGO_HOME, RUSTUP_HOME and CARGO_TARGET_DIR pass through from the caller; everything else comes from the env file.
set -uo pipefail
export LC_ALL=C TZ=UTC
unset LANG LANGUAGE
# The closed first-word list: the one place it is held. The falsifier proves it equals the first words of the committed rows.
FIRST_WORDS='bat cargo'
ALPHABET='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_./:=,+-'
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
OUT=${1:?usage: emit-demo-json.sh OUT.json}
rm -f "${OUT:?}" "${OUT:?}.tmp"
die() { echo "FAIL $*" >&2; exit 1; }
for t in jq perl script timeout sha256sum; do command -v "$t" >/dev/null || die "E-TOOL $t not on PATH"; done
ROOT_L=$(cd "${ADS_ROOT:-$(dirname "$0")/../..}" 2>/dev/null && pwd) && ROOT=$(cd "$ROOT_L" && pwd -P) || die "E-INPUT no repository root"
DIR=${ADS_TERM_DIR:-$ROOT/rust/term-demos}
[ -d "$DIR" ] || die "E-INPUT no $DIR"
TGT=${CARGO_TARGET_DIR:-$ROOT/rust/ads-rust/target}
[[ "$TGT" == /* ]] || die "E-INPUT CARGO_TARGET_DIR must be absolute"
while [[ "$TGT" == */ && ${#TGT} -gt 1 ]]; do TGT=${TGT%/}; done   # a trailing slash would defeat the root token rules
mkdir -p "$TGT" && TGT_P=$(cd "$TGT" && pwd -P) || die "E-INPUT target dir $TGT not usable"
export ADS_ROOT=$ROOT
shopt -s nullglob
cmds=("$DIR"/*.cmds)   # byte order: LC_ALL=C above
cwds=("$DIR"/*.cwd)
[ ${#cmds[@]} -gt 0 ] || die "E-INPUT no $DIR/*.cmds (a row comes from a typed-lines file)"
badid=()
for f in "${cmds[@]}" "${cwds[@]}"; do
  id=$(basename "$f"); id=${id%.*}
  [[ "$id" =~ ^[abcdefghijklmnopqrstuvwxyz0123456789]+$ ]] || badid+=("'$id'")
done
[ ${#badid[@]} -eq 0 ] || die "E-ID id not [a-z0-9]+: $(printf '%s\n' "${badid[@]}" | sort -u | tr '\n' ' ')"
# the pinned rows: every row file is listed with its sha256, and every listed file is present with that sha256
rl="$DIR/rows.list"
[ -f "$rl" ] || die "E-ROWS no row list $rl"
declared=(); rowsbad=(); ln=0
while IFS= read -r l || [ -n "$l" ]; do
  ln=$((ln + 1)); l=${l%%#*}; [[ "$l" =~ [^[:space:]] ]] || continue
  if [[ "$l" =~ ^([abcdefghijklmnopqrstuvwxyz0123456789]+)\ ([0123456789abcdef]{64})\ ([0123456789abcdef]{64})$ ]]; then
    d=${BASH_REMATCH[1]}
    [[ " ${declared[*]} " == *" $d "* ]] && { rowsbad+=("declared twice: $d"); continue; }
    declared+=("$d")
    for x in "cmds ${BASH_REMATCH[2]}" "cwd ${BASH_REMATCH[3]}"; do
      ext=${x%% *}; pin=${x#* }
      if [ ! -f "$DIR/$d.$ext" ]; then rowsbad+=("declared but has no .$ext: $d")
      elif [ "$(sha256sum < "$DIR/$d.$ext" | cut -d' ' -f1)" != "$pin" ]; then rowsbad+=("pin mismatch: $d.$ext"); fi
    done
  else rowsbad+=("malformed line $ln (want '<id> <sha256 .cmds> <sha256 .cwd>')"); fi
done < "$rl"
for f in "${cmds[@]}" "${cwds[@]}"; do
  b=$(basename "$f"); [[ " ${declared[*]} " == *" ${b%.*} "* ]] || rowsbad+=("not declared: $b")
done
[ ${#rowsbad[@]} -eq 0 ] || die "E-ROWS $(IFS=';'; echo "${rowsbad[*]}")"
for c in "${cmds[@]}"; do
  grep -qE '[^[:space:]]' "$c" || die "E-EMPTY term-$(basename "$c" .cmds): .cmds has no command line"
done
# the closed command form: every line of every file, before anything runs
export F_WORDS=$FIRST_WORDS F_ALPHA=$ALPHABET
formbad=0
for c in "${cmds[@]}"; do
  perl -e '
    my ($file, $name) = @ARGV; my %first = map { $_ => 1 } split / /, $ENV{F_WORDS};
    my %ok = map { $_ => 1 } split //, $ENV{F_ALPHA}; $ok{" "} = 1;
    open my $F, "<:raw", $file or die "$file: $!"; local $/ = "\n"; my ($n, $bad) = (0, 0);
    while (my $l = <$F>) {
      $n++; $l =~ s/\n\z//; my $r;
      if ($l eq "") { $r = "empty line" }
      elsif (my ($b) = grep { !$ok{$_} } split //, $l) { $r = sprintf "byte 0x%02x is outside the alphabet", ord $b }
      elsif ($l !~ /\A[^ ]+(?: [^ ]+)*\z/) { $r = "not words joined by single spaces" }
      else { my ($w) = split / /, $l;
             if ($w =~ /=/) { $r = "first word \x27$w\x27 is an assignment" }
             elsif (!$first{$w}) { $r = "first word \x27$w\x27 is not in the closed list ($ENV{F_WORDS})" } }
      next unless defined $r;
      (my $show = substr($l, 0, 80)) =~ s/([^\x20-\x7e])/sprintf "\\x%02x", ord $1/ge;
      print STDERR "FAIL E-FORM $name:$n $r: $show\n"; $bad++;
    }
    exit($bad ? 1 : 0)' "$c" "$(basename "$c")" || formbad=$((formbad + 1))
done
[ "$formbad" -eq 0 ] || die "E-FORM $formbad file(s) with a line outside the closed command form"
work=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/term-demos.XXXXXX") || die "E-INPUT no work dir"
work=$(cd "$work" && pwd -P)
[ -n "${TERM_DEMO_KEEP:-}" ] || trap 'rm -rf "${work:?}"' EXIT
mkdir -p "$work/home"
owned='HOME|PATH|CARGO_HOME|RUSTUP_HOME|CARGO_TARGET_DIR|LC_ALL|LANG|LANGUAGE|TZ|GIT_CONFIG_[A-Z0-9_]+|GIT_CONFIG'
envv=()
if [ -f "$DIR/env" ]; then mapfile -t envv < <(grep -vE '^\s*(#|$)' "$DIR/env"); fi
for kv in "${envv[@]}"; do [[ "$kv" =~ ^($owned|LC_[A-Z]+)= ]] && die "E-ENV term-demos/env sets ${kv%%=*}, which the emitter owns"; done
CH=${CARGO_HOME:-$HOME/.cargo}; RH=${RUSTUP_HOME:-$HOME/.rustup}
envv+=("HOME=$work/home" "PATH=$PATH" "CARGO_HOME=$CH" "RUSTUP_HOME=$RH" "CARGO_TARGET_DIR=$TGT" "LC_ALL=C" "TZ=UTC")
# git in a row reads no system or global config file and trusts the repository root and nothing else (command-line scope)
envv+=("GIT_CONFIG_NOSYSTEM=1" "GIT_CONFIG_GLOBAL=/dev/null" "GIT_CONFIG_COUNT=1" "GIT_CONFIG_KEY_0=safe.directory" "GIT_CONFIG_VALUE_0=$ROOT")
strip() { perl -pe 's/\e\][^\a\e]*(\a|\e\\)//g; s/\e\[[0-?]*[ -\/]*[@-~]//g; s/\e[()][A-Z0-9]//g; s/\e[=>]//g; s/\r//g'; }
export N_TGT=$TGT N_TGT_P=$TGT_P N_ROOT=$ROOT_L N_ROOT_P=$ROOT
normalise() { # N1..N3
  perl -ne '
    BEGIN { my %m; for ([$ENV{N_TGT}, "target"], [$ENV{N_TGT_P}, "target"], [$ENV{N_ROOT}, "."], [$ENV{N_ROOT_P}, "."]) {
              $m{$_->[0]} = $_->[1] if length $_->[0] > 1 } @r = map { [$_, $m{$_}] } sort { length $b <=> length $a } keys %m }
    for my $x (@r) { s/\Q$x->[0]\E/$x->[1]/g }
    next if /^( *)(Compiling|Checking|Fresh|Downloading|Downloaded|Blocking|Updating|Locking|Adding|Unpacking) / && length($1) + length($2) == 12;
    s{(\btarget/[^\s()\x27"]*-)[0-9a-f]{16}\b}{${1}0000000000000000}g;
    s/ in [0-9]+(\.[0-9]+)?s\b/ in 0.00s/g;
    s/\bcommit=[0-9a-f]{40}\b/commit=0000000000000000000000000000000000000000/g;
    s/^( *(polars|btreemap): )[0-9.]+ ms$/${1}0.000000 ms/;
    print'
}
export L_HOME=${HOME:-} L_CH=$CH L_RH=$RH L_TMP=${TMPDIR:-} L_WORK=$work L_RT=${RUNNER_TEMP:-}
leaks() { # N4: FILE -> "line N: reason" for the first survivor; non-zero when one is found
  perl -ne '
    BEGIN { @lit = grep { length > 1 } map { s{/+$}{}r } @ENV{qw(L_HOME L_CH L_RH L_TMP L_WORK L_RT)} }
    chomp; my $why;
    for my $x (@lit) { if (index($_, $x) >= 0) { $why = "host path"; last } }
    $why //= "absolute path" if m{(^|[^A-Za-z0-9_.~-])/(home|tmp|root|Users|runner|github|__w|mnt|var/folders|private)(/|\b)};
    # Whole decimal literals are not hex runs: blank out [+-]D.digits[(e|E)[+-]E] (D at most 15 digits, E at most 3) only
    # when the characters before and after it are line edge or not [A-Za-z0-9_.+-]; anything glued into a longer token stays scanned.
    (my $t = $_) =~ s/(?<![A-Za-z0-9_.+-])[+-]?[0-9]{1,15}\.[0-9]+(?:[eE][+-]?[0-9]{1,3})?(?![A-Za-z0-9_.+-])/ /g;
    unless ($why) { for my $h ($t =~ /[0-9a-f]{16,}/g) { next if $h eq "0" x 16 || $h eq "0" x 40; $why = "volatile hex run (" . length($h) . " chars)"; last } }
    if ($why) { print "line $.: $why: ", substr($_, 0, 160), "\n"; exit 1 }' "$1"
}
cat > "$work/run.sh" <<'RUN'
# run.sh CMDS STATUS: the session. STATUS gets "<line number> <status>", or "end 0" after the last line.
# Every line is already in the closed form (single-space-separated words of the alphabet), so its words are its argv.
stty cols 93 rows 25 2>/dev/null
__n=0; __st=$2
trap '__s=$?; printf "%s %s\n" "$__n" "$__s" > "$__st"' EXIT
set -e -o pipefail
__ln=0
while IFS= read -r -u 3 __l || [ -n "$__l" ]; do
  __ln=$((__ln + 1))
  printf '$ %s\n' "$__l"
  if [ -n "${ECHO_ONLY:-}" ]; then printf '\0'; continue; fi
  __n=$__ln
  IFS=' ' read -r -a __w <<<"$__l"
  "${__w[@]}" || exit $?
done 3< "$1"
__n=end; exit 0
RUN
crate="$ROOT/rust/ads-rust"
if [ -n "${ADS_WARM+x}" ]; then warm=$ADS_WARM; else warm='cargo test --locked --offline --no-run && cargo build --locked --offline --examples'; fi
( cd "$crate" 2>/dev/null || cd "$ROOT"; env -i "${envv[@]}" bash --norc --noprofile -c "$warm" ) >"$work/warm.log" 2>&1 </dev/null || die "E-WARM warm-up failed: $(tail -n 5 "$work/warm.log")"
rows="$work/rows.jsonl"; : > "$rows"; bad=()
test_facts() { # FILE -> reason on stdout, non-zero when the transcript's test facts are not acceptable
  local f=$1 p fl i
  grep -qE '^test result:' "$f" || { echo "no test result line"; return 1; }
  read -r p fl i < <(grep -E '^test result:' "$f" | awk '{ for (k = 1; k < NF; k++) { if ($(k+1) ~ /^passed/) p += $k; if ($(k+1) ~ /^failed/) fl += $k; if ($(k+1) ~ /^ignored/) i += $k } } END { print p+0, fl+0, i+0 }')
  [ "$fl" -eq 0 ] || { echo "$fl failed"; return 1; }
  [ "$i" -eq 0 ] || { echo "$i ignored (an ignored test is not attested)"; return 1; }
  [ "$p" -gt 0 ] || { echo "passed == 0 (no test ran)"; return 1; }
}
n=0
for c in "${cmds[@]}"; do
  id=$(basename "$c" .cmds); why=()
  cwd=$(head -n 1 "$DIR/$id.cwd")
  [[ -n "$cwd" && "$cwd" != /* && "/$cwd/" != */../* && -d "$ROOT/$cwd" ]] || die "E-CWD term-$id: cwd '$cwd' is not a directory under the root"
  st="$work/$id.status"; rm -f "${st:?}"
  ( cd "$ROOT/$cwd" && env -i "${envv[@]}" timeout "${TERM_DEMO_TIMEOUT_S:-2400}" \
      script -qefc "bash --norc --noprofile $(printf '%q %q %q' "$work/run.sh" "$c" "$st")" /dev/null ) \
    > "$work/$id.raw" 2>&1 </dev/null && rc=0 || rc=$?
  strip < "$work/$id.raw" | normalise > "$work/$id.txt"
  line=; s=; [ -s "$st" ] && read -r line s < "$st"
  if [ "$rc" -eq 124 ]; then why+=("E-TIMEOUT session timed out after ${TERM_DEMO_TIMEOUT_S:-2400}s (at line ${line:-?})")
  elif [ -z "$s" ]; then why+=("E-NOSTATUS no status record (session exit $rc)"); [ "$rc" -ne 0 ] || rc=1
  elif [ "$s" != 0 ]; then why+=("E-STATUS line $line exit $s$(case $s in 126|127) echo ' (not runnable)';; esac)"); rc=$s
  elif [ "$line" != end ]; then why+=("E-NOSTATUS no end record (last record: line $line, status 0)"); rc=1
  elif [ "$rc" -ne 0 ]; then why+=("E-STATUS session exit $rc with status record 0")
  fi
  # The checks below run on a session that completed, so a refusal names one cause.
  if [ ${#why[@]} -eq 0 ]; then
  # Every command must appear in the transcript, in order, exactly as it was shown.
  ECHO_ONLY=1 bash --norc --noprofile "$work/run.sh" "$c" /dev/null > "$work/$id.want" 2>/dev/null || true
  perl -e 'local $/; open my $W, "<", $ARGV[0] or die; my @w = split /\0/, <$W>; open my $T, "<", $ARGV[1] or die; my $t = <$T>;
    my $at = 0; for my $x (@w) { my $i = index($t, $x, $at); if ($i < 0) { print "missing: $x"; exit 1 } $at = $i + length $x } exit(@w ? 0 : 1)' \
    "$work/$id.want" "$work/$id.txt" > "$work/$id.miss" || why+=("E-TRANSCRIPT $(head -c 200 "$work/$id.miss")")
  if grep -qE '^cargo test( |$)' "$c"; then
    f=$(test_facts "$work/$id.txt") || why+=("E-TESTS $f")
  fi
  l=$(leaks "$work/$id.txt") || why+=("E-LEAK $l")
  fi
  jq -n --arg id "term-$id" --rawfile cmds "$c" --rawfile so "$work/$id.txt" \
    --argjson rc "$rc" --arg sha "$(sha256sum "$work/$id.txt" | cut -d' ' -f1)" \
    '{id:$id, command:$cmds, commands:($cmds|rtrimstr("\n")|split("\n")), exit:$rc, stdout:$so, stdout_sha256:$sha, plots:[]}' >> "$rows" || die "term-$id row jq"
  echo "term-$id $(wc -c < "$work/$id.txt") bytes exit=$rc"
  if [ ${#why[@]} -gt 0 ]; then
    for w in "${why[@]}"; do echo "FAIL ${w%% *} term-$id ${w#* }" >&2; bad+=("term-$id"); done
    { echo "--- term-$id transcript (last 20 lines)"; tail -n 20 "$work/$id.txt"; } >&2
  fi
  n=$((n + 1))
done
[ ${#bad[@]} -eq 0 ] || die "${#bad[@]} refusal(s): ${bad[*]}"
commit=${GITHUB_SHA:-$(git -c safe.directory="$ROOT" -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)}
jq -s --arg commit "$commit" --arg wf "${GITHUB_WORKFLOW:-local}" --arg run "${GITHUB_RUN_ID:-local}" \
  '{schema:"demo-json/v1",course:"ads-c01-rust",commit:$commit,workflow:$wf,run_id:$run,demos:.}' "$rows" >"$OUT.tmp" || { rm -f "${OUT:?}.tmp"; die "final jq"; }
[ "$(jq -s 'length' "$rows")" -eq "${#declared[@]}" ] && [ "$n" -eq "${#declared[@]}" ] || { rm -f "${OUT:?}.tmp"; die "E-ROWS emitted $n rows, declared ${#declared[@]}"; }
mv "$OUT.tmp" "$OUT"
echo "wrote $OUT ($n demos)"
