#!/usr/bin/env bash
# image-digest.sh TAG : content-derived image digest = sha256 over the rootfs layer diff-ids plus the stable config (Env, Cmd, Entrypoint, User, WorkingDir, ExposedPorts, Labels). The image Id differs per build of the same inputs under the docker containerd store (measured: same layers, different Id), so it is never compared. Exit 2 = could not measure.
set -uo pipefail
tag=${1:?usage: image-digest.sh TAG}
ids=$(docker image inspect "$tag" --format '{{range .RootFS.Layers}}{{.}}{{"\n"}}{{end}}' 2>/dev/null)
[ -n "$ids" ] || { echo "NOT MEASURED: no layers for $tag" >&2; exit 2; }
cfg=$(docker image inspect "$tag" --format '{{json .Config.Env}} {{json .Config.Cmd}} {{json .Config.Entrypoint}} {{json .Config.User}} {{json .Config.WorkingDir}} {{json .Config.ExposedPorts}} {{json .Config.Labels}}' 2>/dev/null) || exit 2
printf 'sha256:%s\n' "$(printf '%s\n%s\n' "$ids" "$cfg" | sha256sum | cut -d' ' -f1)"
