#!/usr/bin/env bash
# Falsifier for lab-readme.sh: each planted defect is refused; the real files pass.
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd); t="$here/tests/lab-readme.sh"; i="$here/image"
S=$(mktemp -d); trap 'rm -rf "${S:?}"' EXIT; fail=0
bash "$t" >"$S/g.out" 2>&1 && echo "arm green ok: $(tail -n 1 "$S/g.out")" || { echo "FAIL arm green: $(tail -n 1 "$S/g.out")"; fail=1; }
arm() { # name dockerfile start supervisord
  if bash "$t" "$2" "$3" "$4" >"$S/a.out" 2>&1; then echo "FAIL arm accepted: $1"; fail=1; else echo "arm RED as planned: $1 -> $(tail -n 1 "$S/a.out")"; fi; }
grep -v '^COPY --chown=coder:coder lab-README.md' "$i/Dockerfile" >"$S/D.nocopy"; arm "no README COPY" "$S/D.nocopy" "$i/start.sh" "$i/supervisord.conf"
grep -v 'cp -f /opt/ads-lab/README.md' "$i/start.sh" >"$S/s.noseed"; arm "no README seed" "$i/Dockerfile" "$S/s.noseed" "$i/supervisord.conf"
{ cat "$i/Dockerfile"; echo 'RUN mkdir /home/coder/go'; } >"$S/D.go"; arm "planted ~/go" "$S/D.go" "$i/start.sh" "$i/supervisord.conf"
sed 's|/opt/ads-lab/starter/|/home/coder/starter/|' "$i/Dockerfile" >"$S/D.st"; arm "starter under ~" "$S/D.st" "$i/start.sh" "$i/supervisord.conf"
sed 's| /home/coder/project/README.md||' "$i/supervisord.conf" >"$S/v.noreadme"; arm "code-server without README" "$i/Dockerfile" "$i/start.sh" "$S/v.noreadme"
sed 's|^cd /home/npm-global.*$|cd /home/coder/|' "$i/start.sh" >"$S/s.npm"; arm "npm init in ~" "$i/Dockerfile" "$S/s.npm" "$i/supervisord.conf"
exit "$fail"
