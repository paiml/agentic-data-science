#!/usr/bin/env bash
# LAB ticket keeper for the nightly lab lane (agentic-data-science#143). ONE ticket, ONE owner, then silence.
#   lab-report.sh stopcheck          exit 3 = the lane is STOPPED (open ticket labelled lab-stopped); labels it once red >= 7 days.
#   lab-report.sh report RC SUMMARY  RC from lab-nightly.sh: 0 closes the open ticket quietly; 1 or 2 opens it, or updates its body in place.
# The ticket is the lane's only state: open = red or unmeasured since its creation (green closes it), so its age is the red age.
# The owner brings a stopped lane back by closing the ticket. Writes go through REST and the returned object is checked (GH-2).
# Env: GH (default gh), REPO (owner/name), LAB_OWNER (assignee), NOW (epoch, tests), RUN_URL.
set -uo pipefail
GH=${GH:-gh}; REPO=${REPO:?REPO=owner/name}; OWNER=${LAB_OWNER:-noahgift}; NOW=${NOW:-$(date +%s)}
LABEL=lab-nightly; STOP=lab-stopped; LIMIT=$((7 * 86400))
find_ticket() { # -> "number<TAB>created_at<TAB>labels" of the open lab-nightly ticket, empty if none
  $GH api "repos/$REPO/issues?labels=$LABEL&state=open&per_page=1" --jq '.[0] // empty | [.number, .created_at, (.labels | map(.name) | join(","))] | @tsv'
}
t=$(find_ticket) || { echo "lab-report: could not read the ticket: NOT MEASURED" >&2; exit 4; }
n=$(printf '%s' "$t" | cut -f1); created=$(printf '%s' "$t" | cut -f2); labels=$(printf '%s' "$t" | cut -f3)
case "${1:-}" in
stopcheck)
  [ -n "$n" ] || exit 0
  case ",$labels," in *",$STOP,"*) echo "lab-nightly STOPPED: ticket #$n is labelled $STOP; its owner closes it to bring the lane back"; exit 3;; esac
  age=$((NOW - $(date -d "$created" +%s)))
  if [ "$age" -ge "$LIMIT" ]; then
    r=$($GH api -X POST "repos/$REPO/issues/$n/labels" -f "labels[]=$STOP" --jq '.[0].name // empty') && [ -n "$r" ] || { echo "lab-report: could not label #$n $STOP" >&2; exit 4; }
    echo "lab-nightly STOPPED: red or unmeasured for 7 days (ticket #$n)"; exit 3
  fi
  exit 0;;
report)
  rc=${2:?RC}; sum=${3:?SUMMARY file}
  if [ "$rc" = 0 ]; then
    [ -n "$n" ] || exit 0
    r=$($GH api -X PATCH "repos/$REPO/issues/$n" -f state=closed -f state_reason=completed --jq '.state // empty') && [ "$r" = closed ] || { echo "lab-report: could not close #$n" >&2; exit 4; }
    exit 0
  fi
  [ "$rc" = 1 ] && what=RED || what=UNMEASURED
  body=$(printf 'Nightly LAB lane %s (lane|status|detail):\n\n```\n%s\n```\n\nRun: %s\nLAB, not a gate: it blocks nothing. Owner: @%s. Red or unmeasured for 7 days stops the lane (label `%s`); close this ticket to bring it back.\n' \
    "$what" "$(cat "$sum")" "${RUN_URL:-local}" "$OWNER" "$STOP")
  if [ -n "$n" ]; then
    r=$($GH api -X PATCH "repos/$REPO/issues/$n" -f "body=$body" --jq '.number // empty') && [ "$r" = "$n" ] || { echo "lab-report: could not update #$n" >&2; exit 4; }
  else
    r=$($GH api -X POST "repos/$REPO/issues" -f "title=LAB: nightly lab proofs $what" -f "body=$body" -f "labels[]=$LABEL" -f "assignees[]=$OWNER" --jq '.number // empty') && [ -n "$r" ] || { echo "lab-report: ticket create returned no object" >&2; exit 4; }
  fi
  exit 0;;
*) echo "usage: lab-report.sh stopcheck | report RC SUMMARY" >&2; exit 64;;
esac
