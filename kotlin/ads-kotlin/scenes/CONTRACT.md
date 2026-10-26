# Scene file contract (`scenes/*.scene`)

One `key = value` per line. The recorder reads these; the tests in
`SceneContractTest` and `MeasuredRealOutputTest` hold them.

## `cwd` (N6)

- The recorder has ONE base: the **repo root** (the directory that
  holds `kotlin/`, `datasets/` and `Makefile`). It is the
  `ads.root` the tests resolve.
- Every scene names `cwd`, a path **relative to that base**, with no
  leading `/` and no `..`. The recorder does `cd <base>/<cwd>`
  before it types `run`.
- The directory must exist. A `./gradlew` run needs an executable
  `gradlew` in it; a `sha256sum -c <file>` run needs `<file>` in it.
- Values in use: `kotlin` (Gradle and pmat) and
  `datasets/penguins` (sha256sum).
- `SceneContractTest` resolves every scene's `cwd` from the base and
  fails on a missing key, a missing directory, a missing `gradlew`
  or sums file. Negative controls prove each failure mode.

## `measured` (N7)

- Present on `tool = kover` scenes. It is a **regular expression**
  (Kotlin `Regex`, MULTILINE), not display text.
- It is matched against the real `koverLog koverLogBranch` output.
  It must hit exactly one `line coverage ...` line and one
  `branch coverage ...` line, and every such line in the output must
  be hit, so a wrong line OR branch number fails.
- The line number is pinned to the line bound (100); the branch
  number is a range from the branch bound (95) to 100.
- `MeasuredRealOutputTest` (task `measuredCheck`, run by
  `scripts/gate-kotlin.sh` on the output it captures from the live
  tasks) matches each scene's pattern against that output.
  `SceneContractTest` holds the negative controls (a wrong number
  must FAIL).

## `file` (second base)

- `file` is the one key that does NOT use the repo-root base: it is
  relative to the **module directory** `kotlin/ads-kotlin`, the
  directory the tests resolve as `ads.scenes/..`. The recorder shows
  `<repo root>/kotlin/ads-kotlin/<file>`.
- The file must exist there; `lines` and `ticks` index into it.
- So a scene has two bases: `cwd` (repo root) where the command
  runs, and `file` (module directory) for the code shown.
