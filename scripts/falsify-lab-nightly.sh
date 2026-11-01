#!/usr/bin/env bash
# Falsifier for the nightly LAB lane (#143). An arm that cannot flip proves nothing: each FORGE arm plants a defect a grader would PASS
# and the lane must go RED (rc 1); the clean arm must be GREEN; an absent toolchain must be rc 2 (never green); the ticket keeper is
# driven with a fake gh. LAB only: run at night, never in PR CI. An arm whose toolchain is absent prints "NOT RUN", never "ok".
# Env: SKIP_HEAVY=1 skips the arms that run cargo (keeps R, julia and the keeper arms).
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
BASHBIN=$(command -v bash)
S=$(mktemp -d); trap 'rm -rf "${S:?}"' EXIT
fail=0; notrun=0
ok()  { echo "arm $1 ok: $2"; }
bad() { echo "FAIL arm $1: $2"; fail=1; }
nr()  { echo "arm $1 NOT RUN: $2"; notrun=1; }
copy() { # name: a scratch repo root holding only the three labs
  local d="$S/${1:?}" l
  rm -rf "${d:?}"
  for l in rust r julia; do mkdir -p "$d/$l"; cp -R "$here/$l/lab" "$d/$l/"; done
}
lane() { # name root only [env...] -> rc
  local name=$1 root=$2 only=$3; shift 3
  env LAB_ROOT="$root" LAB_OUT="$S/out-$name" LAB_ONLY="$only" "$@" "$BASHBIN" "$here/scripts/lab-nightly.sh" >"$S/$name.log" 2>&1; echo $?
}
want() { # arm logname rc want
  if [ "$3" = "$4" ]; then ok "$1" "rc=$3 ($(tail -n 1 "$S/$2.log" | cut -c1-90))"; else bad "$1" "rc=$3 want $4: $(tail -n 2 "$S/$2.log" | cut -c1-120)"; fi
}
# ---- lane arms
if command -v Rscript >/dev/null && Rscript -e 'for (p in c("testthat","dplyr","readr","jsonlite","tibble")) library(p, character.only = TRUE)' >/dev/null 2>&1; then
  copy a; want A-r-clean a "$(lane a "$S/a" r)" 0
  copy b
  for v in starter solution; do printf 'library(testthat)\ntest_that("forged", expect_true(TRUE))\n' > "$S/b/r/lab/penguin-summary/$v/tests/test-lab.R"; done
  want B-r-forged-tests b "$(lane b "$S/b" r)" 1
else nr A-r-clean "Rscript absent"; nr B-r-forged-tests "Rscript absent"; fi
if [ "${SKIP_HEAVY:-0}" != 1 ] && command -v cargo >/dev/null; then
  copy c
  for v in starter solution; do printf '#[test]\nfn forged() {}\n' > "$S/c/rust/lab/penguin-summary/$v/tests/lab.rs"; done
  want C-rust-forged-tests c "$(lane c "$S/c" rust)" 1
else nr C-rust-forged-tests "cargo absent or SKIP_HEAVY"; fi
JL=${JULIA:-}; [ -n "$JL" ] || JL=$(command -v julia || true)
if [ -n "$JL" ]; then
  copy d
  g="$S/d/julia/lab/penguin-summary/grade.sh"
  sed -i '/^\[ -f "\$result" \] || /d;/^\[ "\$got_nonce" = /d;/^case "\$pass\$fail\$error" in/d;s|^read -r got_nonce pass fail error < "\$result"|got_nonce=x; pass=; fail=; error=|' "$g"
  cmp -s "$g" "$here/julia/lab/penguin-summary/grade.sh" && bad D-julia-grader-forge "the grade.sh mutation changed nothing"
  want D-julia-grader-forge d "$(lane d "$S/d" julia JULIA="$JL")" 1
else nr D-julia-grader-forge "julia absent"; fi
# floor: a proof that exits 0 and prints nothing is RED, not green
if command -v cargo >/dev/null; then
  copy e; printf '#!/usr/bin/env bash\nexit 0\n' > "$S/e/rust/lab/penguin-summary/run-lab-proof.sh"
  want E-empty-proof-is-red e "$(lane e "$S/e" rust)" 1
else nr E-empty-proof-is-red "cargo absent"; fi
# absent toolchain: rc 2, never 0
copy f; want F-absent-toolchain-is-unmeasured f "$(lane f "$S/f" r PATH=/nonexistent)" 2
# ---- workflow lint: LAB only, no hosted runner, no PR-path trigger
w=$here/.github/workflows/lab-nightly.yml
TRIG='pull_request_target|pull_request|merge_group|push|workflow_call'
trig_flat() { grep -Eq "^\s*[\"']?($TRIG)[\"']?\s*:|^[\"']?on[\"']?\s*:.*\b($TRIG)\b" "$1"; }
# block-list form (`on:` then `- pull_request` lines): no YAML parser is on the fleet (no yq), so awk walks the top-level `on:` block
trig_list() { awk -v t="^[[:space:]]*-[[:space:]]*[\"']?($TRIG)[\"']?[[:space:]]*(#.*)?$" '
  /^["'"'"']?on["'"'"']?:[[:space:]]*(#.*)?$/ { inon = 1; next }
  /^[^[:space:]#]/ && !/^-[[:space:]]/ { inon = 0 }
  inon && $0 ~ t { bad = 1 }
  END { exit !bad }' "$1"; }
trig_bad() { trig_flat "$1" || trig_list "$1"; }
if trig_bad "$w"; then bad G-workflow-triggers "a PR-path or reusable trigger is present"; else grep -q 'schedule:' "$w" && ok G-workflow-triggers "schedule + workflow_dispatch only"; fi
# mutants: each forbidden trigger planted into a scratch copy must turn the lint red (an arm that cannot flip proves nothing)
for tr in pull_request_target workflow_call pull_request merge_group push; do
  m="$S/wf-$tr.yml"; sed "s/^  workflow_dispatch: {}/  workflow_dispatch: {}\n  $tr: {}/" "$w" > "$m"
  if cmp -s "$m" "$w"; then bad "G-mutant-$tr" "the plant changed nothing"; elif trig_bad "$m"; then ok "G-mutant-$tr" "lint goes red"; else bad "G-mutant-$tr" "lint stayed green with $tr planted"; fi
done
m="$S/wf-inline.yml"; sed 's/^on:$/on: [pull_request_target]/' "$w" > "$m"
if cmp -s "$m" "$w"; then bad G-mutant-inline "the plant changed nothing"; elif trig_bad "$m"; then ok G-mutant-inline "inline on: [..] form goes red"; else bad G-mutant-inline "inline form stayed green"; fi
# quoted keys and the bare / flow / single-quoted `on:` forms (the YAML spellings the plain key regex missed)
mutwf() { # name sed-expr
  local m="$S/wf-$1.yml"; sed "$2" "$w" > "$m"
  if cmp -s "$m" "$w"; then bad "G-mutant-$1" "the plant changed nothing"; elif trig_bad "$m"; then ok "G-mutant-$1" "lint goes red"; else bad "G-mutant-$1" "lint stayed green"; fi
}
mutwf quoted-key '/^  workflow_dispatch: {}/a\  "pull_request_target": {}'
mutwf squoted-key "/^  workflow_dispatch: {}/a\\  'workflow_call': {}"
mutwf on-push-plain 's/^on:$/on: push/'
mutwf on-flow-list 's/^on:$/on: [workflow_dispatch, push]/'
mutwf on-flow-map 's/^on:$/on: { pull_request_target: {} }/'
mutwf on-quoted '0,/^on:$/s//"on": push/'
# block-list form: `on:` followed by `- <trigger>` lines
mutwf list-pr '/^on:$/a\  - pull_request'
mutwf list-prt "/^on:\$/a\\  - 'pull_request_target'"
mutwf list-quoted-comment '/^on:$/a\  - "push"  # sneaky'
mutwf list-after-schedule '/^  workflow_dispatch: {}/a\  - workflow_call'
# indent-0 block list: `on:` then `- push` flush left (a valid YAML sequence under a mapping key)
mutwf list-indent0 '/^on:$/a\- push'
mutwf list-indent0-quoted "/^on:\$/a\\- 'pull_request_target'"
# stop-rule control: a `- pull_request` list item under jobs: is not a trigger and must stay GREEN (the walk ends at the next top-level key)
ctl="$S/wf-ctl-jobs.yml"; { cat "$w"; printf '      - pull_request\n'; } > "$ctl"; sed -i 's/^jobs:$/jobs:\n  note:\n    steps:\n      - pull_request/' "$ctl"
if cmp -s "$ctl" "$w"; then bad G-control-jobs-list "the control plant changed nothing"; elif trig_bad "$ctl"; then bad G-control-jobs-list "a list item under jobs: was flagged as a trigger"; else ok G-control-jobs-list "stays green"; fi
if grep -Eq 'ubuntu|windows|macos' "$w"; then bad H-workflow-runner "a hosted runner label is present"; else ok H-workflow-runner "self-hosted pin"; fi
if grep -Eq 'continue-on-error|sudo|apt-get' "$w"; then bad H2-workflow-states "continue-on-error or an install on the host"; else ok H2-workflow-states "none"; fi
# ---- ticket keeper with a fake gh
cat > "$S/gh" <<'GH'
#!/usr/bin/env bash
echo "$*" >> "$FAKE_LOG"
case "$*" in
  *"issues?labels="*) printf '%s' "${FAKE_TICKET:-}";;
  *"-X POST"*"/labels"*) echo lab-stopped;;
  *"-X POST"*"/issues "*) printf '%s' "${FAKE_CREATE-77}";;
  *"state=closed"*) echo closed;;
  *"-X PATCH"*) echo "${FAKE_N:-5}";;
esac
GH
chmod +x "$S/gh"
echo 'LAB|x' > "$S/sum"
NOWE=$(date -d 2026-11-10 +%s)
keep() { # name expected-rc must-grep mustnot-grep [env...]; lab-report args in KARGS
  local name=$1 want=$2 must=$3 mustnot=$4 rc; shift 4
  : > "$S/calls"
  env GH="$S/gh" REPO=o/r FAKE_LOG="$S/calls" NOW="$NOWE" "$@" bash "$here/scripts/lab-report.sh" $KARGS >/dev/null 2>&1; rc=$?
  [ "$rc" = "$want" ] || { bad "$name" "rc=$rc want $want"; return; }
  tr "\n" " " < "$S/calls" > "$S/flat"
  [ -z "$must" ] || grep -Eq -- "$must" "$S/flat" || { bad "$name" "expected call /$must/ missing: $(tr '\n' ';' < "$S/calls" | cut -c1-160)"; return; }
  [ -z "$mustnot" ] || ! grep -Eq -- "$mustnot" "$S/flat" || { bad "$name" "forbidden call /$mustnot/ made"; return; }
  ok "$name" "rc=$rc"
}
T5=$(printf '5\t2026-11-09T00:00:00Z\tlab-nightly')
KARGS="report 1 $S/sum"
keep K1-red-no-ticket-opens-one 0 'POST repos/o/r/issues .*assignees' 'PATCH' FAKE_TICKET=
keep K2-red-ticket-updates-in-place 0 'PATCH repos/o/r/issues/5 ' '-X POST repos/o/r/issues ' FAKE_TICKET="$T5"
KARGS="report 2 $S/sum"
keep K3-unmeasured-same-as-red 0 'PATCH repos/o/r/issues/5 ' '-X POST repos/o/r/issues ' FAKE_TICKET="$T5"
KARGS="report 0 $S/sum"
keep K4-green-closes-ticket 0 'state=closed' 'body=' FAKE_TICKET="$T5"
keep K5-green-no-ticket-silent 0 'issues\?labels' 'POST|PATCH' FAKE_TICKET=
KARGS="report 1 $S/sum"
keep K6-create-returning-null-is-loud 4 '' '' FAKE_TICKET= FAKE_CREATE=
KARGS="stopcheck"
keep K7-fresh-ticket-runs 0 '' 'labels\b.*POST|PATCH' FAKE_TICKET="$T5"
keep K8-eight-day-red-stops 3 '-X POST repos/o/r/issues/5/labels' '' FAKE_TICKET="$(printf '5\t2026-11-01T00:00:00Z\tlab-nightly')"
keep K9-stopped-label-stays-stopped 3 '' '-X POST' FAKE_TICKET="$(printf '5\t2026-11-01T00:00:00Z\tlab-nightly,lab-stopped')"
if [ "$fail" -eq 0 ]; then
  [ "$notrun" -eq 1 ] && echo "falsifier OK for the arms that ran (some NOT RUN above)" || echo "falsifier OK (all arms ran)"
fi
exit "$fail"
