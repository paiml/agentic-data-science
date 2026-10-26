#!/usr/bin/env bash
# Install elan 4.2.4 (pinned, sha256-verified) into ~/.elan. It installs no
# Lean toolchain; lake picks the one in lean-toolchain on first use.
set -euo pipefail
v=4.2.4
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) t=x86_64-unknown-linux-gnu; h=42b94d4244e8353142c456ec0e4ca6528fd898a6c604d4059f494e706e431f63 ;;
  Linux-aarch64) t=aarch64-unknown-linux-gnu; h=05febd124d84ebf994b2e7479922a5650b1e950c17ae3bd1ddd776b65bb72bf9 ;;
  Darwin-arm64) t=aarch64-apple-darwin; h=7ad829861392c718dfebde3a83b5c8508df47be02af68894b094b0b3952616e5 ;;
  Darwin-x86_64) t=x86_64-apple-darwin; h=8a340b309d8ed2e96f930761fa223b3af57a38f5d253b53ac90293c9516f8cd4 ;;
  *) echo "install-elan: unsupported platform $(uname -sm)" >&2; exit 1 ;;
esac
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp:?}"' EXIT
curl -fsSL -o "$tmp/elan.tgz" "https://github.com/leanprover/elan/releases/download/v$v/elan-$t.tar.gz"
echo "$h  $tmp/elan.tgz" > "$tmp/elan.sha"
if command -v sha256sum >/dev/null; then sha256sum -c "$tmp/elan.sha"; else shasum -a 256 -c "$tmp/elan.sha"; fi
tar -xzf "$tmp/elan.tgz" -C "$tmp"
"$tmp/elan-init" -y --default-toolchain none
