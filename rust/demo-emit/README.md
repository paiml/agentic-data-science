# demo-emit

Std-only Rust program (no dependencies) that emits `demo.json` for the Rust course. It runs each line of `rust/term-demos/<id>.cmds` as an **argv, with no shell**: nothing is parsed, expanded, evaluated or piped, so a line cannot hide a failing command behind `;`, `&&`, `$(...)`, quoting, `eval`, `trap` or a redirect.

```
demo-emit [--root DIR] [--term-dir DIR] [--no-warm] [--timeout-s N] OUT.json
```

Exit 0: `OUT.json` written. Exit 1: a refusal (`FAIL <code> <message>` on stderr; no file is left). Exit 2: usage error.

## The closed form of a line

A byte outside `[A-Za-z0-9_./:=,+@-]`, space and tab refuses the whole file (E-FORM, named `<id>.cmds:<line>`). The first word must be `[A-Za-z0-9_-]+`, not contain `=`, and be in `ALLOWED_PROGRAMS` (`bat`, `cargo`, `make`; `rust/demo-emit/tests/committed.rs` keeps this equal to the first words of the committed rows). `make` is accepted only as `make gate-shacl`, `make gate-rust` or `make shacl-check` (`MAKE_TARGETS`): any other target, flag, variable or second argument refuses the file (E-FORM). `make` starts those recipes in a shell, so this is the one place a shell runs; it is bounded to those three repo-owned targets. A `.cwd` of a lone `.` is the checkout root. It is resolved in the absolute entries of `PATH` only, never the working directory.

## Staged rows

A staged demo is one typed command that prints a source stage (`== source: FILE RANGE ==` and the lines), waits for one typed line, then prints a run stage (`== run ==` or `== run: ... ==`). Two words that are not programs, and are never spawned, let a row say exactly what a terminal session types:

- `cd DIR`, first line only, one argument: the rest of the row runs in `DIR`, resolved from `<id>.cwd` under the same rule as `<id>.cwd` itself (E-CWD). It prints nothing.
- `run`, no arguments, directly below a `cargo` or `make` line: that command gets `run` and a newline as its whole stdin (then end of input) instead of null stdin.

Any other placement is E-FORM (`CdNotFirst`, `BadCd`, `StrayTyped`). All typed lines, `cd` and `run` included, are the row's `commands`. In `stdout` a `cd` shows as its prompt line alone, and `run` shows where a terminal echoes it: on its own line directly above the run header, with no prompt. The command's output must be a source stage first and exactly one run header after it; anything else is E-STAGE, so `run` under a command that is not staged is refused.

A staged `cargo` command must be the exact `RUN` of at least one row of `demos/rust-native/*.batch` (E-BATCH otherwise, before it runs). When the `WAIT` of such a row contains `test result:`, the row is a staged test row: its run stage (the lines below the run header) is held to the same rule as a plain `cargo test` line (E-TESTS: a result line, no failed or ignored test, passed > 0). A result line in the source stage does not count.

```
cd rust/ads-rust
cargo run -q --locked --offline --example species-profile
run
```

## What the emitter checks

| Code | Refuses |
|---|---|
| E-INPUT | no rows, no `env`, unreadable directory, bad root |
| E-ID | a row file whose id is not `[a-z0-9]+` (bytes, no locale) |
| E-ROWS | a file not in `rows.list`, a listed file missing, a sha256 pin that differs, a malformed or duplicate pin line, any other entry in the directory |
| E-EMPTY / E-FORM | an empty command file / a line outside the closed form |
| E-CWD | a `<id>.cwd`, or its join with a staged row's `cd DIR`, that is not one relative path of `[A-Za-z0-9_.-]` components naming a directory that stays inside the checkout (symlinks resolved) |
| E-ENV | an `env` key outside the closed list, a duplicate, a non-printable value, a relative `CARGO_TARGET_DIR` |
| E-WARM | the unrecorded warm-up (`cargo test --no-run`, `cargo build --examples`, in `rust/ads-rust`) failing |
| E-SPAWN / E-STATUS / E-TIMEOUT | a program that cannot start / a non-zero exit or death by signal (the real status, never 0) / a command past `--timeout-s` (the whole process group is killed). The first one stops the session. |
| E-STAGE | a command with `run` typed below it whose output is not a `== source: ` header line first and exactly one `== run` header after it |
| E-UTF8 | output that is not UTF-8 |
| E-TESTS | a `cargo test` command, or the run stage of a staged test row, with no `test result:` line, a failed or ignored test, or passed == 0 |
| E-BATCH | a staged `cargo` command that is the `RUN` of no row of `demos/rust-native/*.batch` |
| E-LEAK | a host path, or a hex run of 16 or more digits that is not exactly sixteen or forty zeros, left after normalisation |
| E-OUT | `OUT.json` cannot be written (it is written to `OUT.json.tmp` and renamed only after every row passed) |

## The session environment

Each command runs with a cleared environment: the keys of `term-demos/env` (a closed list), plus `HOME` (a scratch directory), `PATH` (absolute entries of the caller's), `CARGO_HOME`, `RUSTUP_HOME`, `CARGO_TARGET_DIR` (absolute), `LC_ALL=C`, `TZ=UTC`, and `GIT_CONFIG_NOSYSTEM`, `GIT_CONFIG_GLOBAL=/dev/null` and a `safe.directory` entry for the checkout. Nothing else is inherited. Stdin is null (a staged command reads its one typed line, then end of input); stdout and stderr share one ordered pipe.

## Normalisation

Checkout and target spellings (logical and physical) become `.` and `target`; cargo status lines are dropped; `-<16 hex>` at the end of a `target/...` path becomes sixteen zeros; ` in 12.34s` becomes ` in 0.00s`; `commit=<40 hex>` and the bench `polars:` / `btreemap:` timings are pinned. Then the leak scan runs over the whole transcript.

## Tests

`cargo test --locked --offline --manifest-path rust/demo-emit/Cargo.toml` (or `make rust-demo-test`). Every evasion named in the review verdicts and every error code is a named test; the binary is driven end to end with fake `bat` and `cargo`; `tests/committed.rs` validates the 20 committed rows and holds the staged rows to the batch files and the crate's example list.
