#!/usr/bin/env bash
# falsify-image-digest.sh : two cached builds of the same inputs must give the same content digest (image-digest.sh); one changed Dockerfile line must change it. Arm C records whether the raw image Id differs between the two builds (the defect the old compare had); informational. Needs docker.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); lab=$(cd "$here/.." && pwd)
command -v docker >/dev/null || { echo "NOT MEASURED: no docker"; exit 2; }
T=$(mktemp -d); trap 'rm -rf "$T"; docker rmi -f lpd-a lpd-b lpd-c >/dev/null 2>&1' EXIT
cp -r "$lab/image" "$T/img"; cp -r "$lab/image" "$T/var"; printf '\nENV IMAGE_DIGEST_FALSIFIER=1\n' >> "$T/var/Dockerfile"
b() { docker build -q --platform linux/amd64 -t "$1" "$2" >/dev/null || { echo "NOT MEASURED: build $1 failed"; exit 2; }; }
b lpd-a "$T/img"; b lpd-b "$T/img"; b lpd-c "$T/var"
da=$(bash "$here/image-digest.sh" lpd-a) || exit 2; db=$(bash "$here/image-digest.sh" lpd-b) || exit 2; dc=$(bash "$here/image-digest.sh" lpd-c) || exit 2
ia=$(docker image inspect lpd-a --format '{{.Id}}'); ib=$(docker image inspect lpd-b --format '{{.Id}}')
echo "A same inputs, two builds: digest equal=$([ "$da" = "$db" ] && echo yes || echo no) (want yes)"
echo "B one changed line: digest differs=$([ "$da" != "$dc" ] && echo yes || echo no) (want yes)"
echo "C raw image Id differs between the two builds=$([ "$ia" != "$ib" ] && echo yes || echo no) (informational: yes = the old Id compare would be RED)"
[ "$da" = "$db" ] && [ "$da" != "$dc" ] && { echo "falsify-image-digest: GREEN"; exit 0; }
echo "falsify-image-digest: RED"; exit 1
