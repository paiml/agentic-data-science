# Lean lab image (Coursera Labs custom image)

Built from Coursera's open-source `vscode` base (Apache-2.0, `LICENSE-coursera-labs`; `coursera/coursera-labs` @ 7cbff49) plus Lean 4 core (no Mathlib).

- Toolchain: read from `../lean-toolchain` (`--build-arg LEAN_TOOLCHAIN`), never typed in the Dockerfile. The elan installer is checked against `elan-init.sh.sha256` and the toolchain is installed at build time (the lab needs no network).
- Patches vs upstream (each step failed at HEAD): Node 14 from the official tarball (nodesource's key is dead); the Go tools, C/C++ vsix, marketplace extensions and the live-server tweak removed; bubblewrap 0.11.0 built from a sha256-pinned tarball (focal's lacks `--clearenv`, which the grader needs).
- Build: `bash ../tests/build-image.sh TAG`. Test: `bash ../tests/image-test.sh TAG` (fresh `--network none` containers).
- The grader runs learner code in the container itself (`GRADER_SANDBOX=container` plus `/etc/ads-lab-container-sandbox`, both set by the image); no bwrap, no added capabilities, works unprivileged. This is not protection against the learner, who has sudo in the upstream base.
- Upload to Lab Manager ("Upload Build Files": a zip with the Dockerfile at its root and the files it COPYs) is Noah's change-list item.
