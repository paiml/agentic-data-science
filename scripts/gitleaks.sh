#!/usr/bin/env bash
# Install pinned gitleaks (sha256-verified) and scan the full git history.
# Usage: scripts/gitleaks.sh <install-dir>
set -euo pipefail
dir="${1:?usage: gitleaks.sh <install-dir>}"
v=8.30.1
h=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb
mkdir -p "$dir"
curl -fsSL -o "$dir/gl.tgz" "https://github.com/gitleaks/gitleaks/releases/download/v$v/gitleaks_${v}_linux_x64.tar.gz"
echo "$h  $dir/gl.tgz" | sha256sum -c -
tar -xzf "$dir/gl.tgz" -C "$dir" gitleaks
"$dir/gitleaks" git . --config .gitleaks.toml --log-opts="--all" --redact --no-banner --exit-code 1
