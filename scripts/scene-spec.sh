#!/usr/bin/env bash
# Scene specs: demos/e-mN/scenes.spec lists, per scene, the exact lines the camera types.
#   == vNN            starts a scene
#   @cwd DIR          directory the terminal starts in (default lean/AgenticDS)
#   @gate             the scene runs the gate itself: `check` only, never replayed
#   @expect-exit N   the hold shows '> exit=N' (default 0): a planted failure the camera must show
#   $ LINE            a line typed verbatim (native tool, never a script)
#   > TEXT            real output that must appear when the lines run
# check:  every typed line is a native command followed by its own `echo "exit=$?"`.
# replay: run the typed lines and assert every `>` text appears and the last exit is 0.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/.elan/bin:$PATH"
mode="${1:?usage: scene-spec.sh check|replay SPEC [ID] | selftest}"
if [ "$mode" = selftest ]; then
  # Negative control: each broken spec must be refused by `check`.
  t=$(mktemp -d)
  refused() { ! bash "$(readlink -f "$0")" check "$t/s.spec" > /dev/null; }
  for bad in "bash demos/e-m1/v01.sh" "lake build > /dev/null" "lake build | grep OK" "printf hi" 'bash -c "lake build | tail"' "./run" "\$(echo lake) build" "env lake build" "\`echo lake\` build" 'echo "Build completed successfully"' "lake build; true" "lake build && true" "sh -c lake" "git push" "rm -rf x" "lake build 2>&1"; do
    printf '== v01\n$ %s\n$ echo "exit=$?"\n> exit=0\n' "$bad" > "$t/s.spec"
    refused || { echo "FAIL selftest: accepted: $bad"; rm -rf "${t:?}"; exit 1; }
  done
  printf '== v01\n@expect-exit 1\n$ lake build\n$ echo "exit=$?"\n> exit=0\n' > "$t/s.spec"
  refused || { echo "FAIL selftest: accepted a hold that ignores @expect-exit"; rm -rf "${t:?}"; exit 1; }
  printf '== v01\n$ lake build\n> exit=0\n' > "$t/s.spec"
  refused || { echo "FAIL selftest: accepted a command with no exit echo"; rm -rf "${t:?}"; exit 1; }
  rm -rf "${t:?}"
  echo "selftest OK: broken specs refused"
  exit 0
fi
spec="${2:?spec file}"
only="${3:-}"
fail=0
bad() { echo "FAIL $spec: $*"; fail=1; }

# scenes SPEC: print scene ids in order.
ids() { grep -E '^== ' "$spec" | cut -c4-; }

# body ID: the spec lines of one scene.
body() { awk -v id="$1" '/^== /{on=($2==id)} on' "$spec"; }

check_scene() {
  local id="$1" prev="" line n=0 typed=0 want
  while IFS= read -r line; do
    case "$line" in
    '$ '*)
      cmd="${line#\$ }"; typed=$((typed + 1))
      if [ "$cmd" = 'echo "exit=$?"' ]; then
        [ -n "$prev" ] || bad "$id: exit echo without a command before it"
        prev=""
      else
        [ -z "$prev" ] || bad "$id: '$prev' has no echo \"exit=\$?\" right after it"
        prev="$cmd"
        # Shell syntax is judged outside quotes (a regex may hold `|`); the words anywhere.
        bare=$(printf '%s' "$cmd" | sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g")
        printf '%s' "$cmd" | grep -qE "^((lake (build|exe|env lean)|make (-C [A-Za-z0-9_./-]+ )?[a-z][a-z0-9-]*|sed -n [0-9]+,[0-9]+p|git (-C [A-Za-z0-9_./-]+ )?(log|status|diff|show|rev-parse)|cat|ls|wc|head|tail|grep|lean)( |$))" ||
          bad "$id: not on the allowlist (lake build|exe|env lean, make TARGET, git log|status|diff|show|rev-parse, cat, ls, wc, head, tail, grep, lean): $cmd"
        printf '%s' "$cmd" | grep -qE '\$\(|\$\{|`|\\[^"]|\\$' && bad "$id: command substitution or escape in typed line: $cmd"
        if printf '%s' "$cmd" | grep -qE '\.sh( |$)|/dev/null|printf|echo "PASS|alias ' ||
          printf '%s' "$bare" | grep -qE '[|;&<>]'; then
          bad "$id: typed line hides or wraps the tool: $cmd"
        fi
      fi ;;
    esac
    n=$((n + 1))
  done < <(body "$id")
  [ -z "$prev" ] || bad "$id: last command '$prev' has no echo \"exit=\$?\""
  [ "$typed" -ge 2 ] || bad "$id: no typed command"
  want=$(body "$id" | awk '/^@expect-exit /{print $2}'); want=${want:-0}
  body "$id" | grep -q "^> exit=$want\$" || bad "$id: the hold must show '> exit=$want'"
}

replay_scene() {
  local id="$1" cwd out want
  cwd=$(body "$id" | awk '/^@cwd /{print $2}')
  out=$(mktemp)
  body "$id" | grep '^\$ ' | cut -c3- > "$out.sh"
  (cd "$root/${cwd:-lean/AgenticDS}" && bash "$out.sh" > "$out" 2>&1)
  while IFS= read -r want; do
    grep -qF -- "${want#> }" "$out" || bad "$id: output lacks '${want#> }'"
  done < <(body "$id" | grep '^> ')
  while IFS= read -r l; do
    body "$id" | grep -qxF "> $l" || bad "$id: unexpected $l"
  done < <(grep -E '^exit=[1-9]' "$out")
  [ -z "${SCENE_SPEC_SHOW:-}" ] || cat "$out"
  rm -f "${out:?}" "${out:?}.sh"
}

for id in $(ids); do
  [ -z "$only" ] || [ "$only" = "$id" ] || continue
  case "$mode" in
  check) check_scene "$id" ;;
  replay)
    check_scene "$id"
    if body "$id" | grep -q '^@gate$'; then echo "$id: gate scene, checked not replayed"; continue; fi
    replay_scene "$id"
    [ "$fail" = 0 ] && echo "$id replay OK" ;;
  *) echo "unknown mode $mode"; exit 2 ;;
  esac
done
[ -n "$(ids)" ] || bad "no scenes"
exit "$fail"
