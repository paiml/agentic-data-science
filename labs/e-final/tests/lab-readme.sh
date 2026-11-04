#!/usr/bin/env bash
# LAB-STD-001 L1/L3/L4 static half for the image: the lab README ships in the image at /opt/ads-lab/README.md and start.sh seeds it
# (cp -f, so it always equals the shipped file) into /home/coder/project; no ~/go; the starter lives outside ~; code-server opens the project with README.md.
# Usage: lab-readme.sh [DOCKERFILE [START.SH [SUPERVISORD.CONF]]]   (optional paths let the falsifier check scratch copies)
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd); d="${1:-$here/image/Dockerfile}"; s="${2:-$here/image/start.sh}"; v="${3:-$here/image/supervisord.conf}"
[ -s "$here/image/lab-README.md" ] || { echo "FAIL: image/lab-README.md is missing or empty"; exit 1; }
grep -q '^COPY --chown=coder:coder lab-README.md /opt/ads-lab/README.md' "$d" || { echo "FAIL: Dockerfile does not COPY lab-README.md to /opt/ads-lab/README.md"; exit 1; }
grep -q 'cp -f /opt/ads-lab/README.md /home/coder/project/README.md' "$s" || { echo "FAIL: start.sh does not seed README.md into /home/coder/project"; exit 1; }
if grep -E -q '/home/coder/go|GOPATH' "$d"; then echo "FAIL: Dockerfile still creates ~/go (L4)"; exit 1; fi
if grep -q '/home/coder/starter' "$d" "$s"; then echo "FAIL: the starter is still under ~ (L4)"; exit 1; fi
grep -q 'code-server .*/home/coder/project /home/coder/project/README.md' "$v" || { echo "FAIL: code-server does not open /home/coder/project with README.md (L3)"; exit 1; }
if grep -q -E "^cd /home/coder/?\s*$" "$s"; then echo "FAIL: start.sh runs npm init in ~ and leaves package.json in the learner home (L4)"; exit 1; fi
echo "PASS: lab README ships and is seeded; no ~/go; starter outside ~; code-server opens project + README"
