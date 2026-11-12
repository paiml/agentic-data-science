# demo-emit

Std-only Rust program (no dependencies) that emits `demo.json` for the Rust course. It runs each line of `rust/term-demos/<id>.cmds` as an **argv, with no shell**: nothing is parsed, expanded, evaluated or piped, so a line cannot hide a failing command behind `;`, `&&`, `$(...)`, quoting, `eval`, `trap` or a redirect.

```
demo-emit [--root DIR] [--term-dir DIR] [--no-warm] [--timeout-s N] OUT.json
```

Exit 0: `OUT.json` written. Exit 1: a refusal (`FAIL <code> <message>` on stderr; no file is left). Exit 2: usage error.

## The closed form of a line

A byte outside `[A-Za-z0-9_./:=,+@-]`, space and tab refuses the whole file (E-FORM, named `<id>.cmds:<line>`). The first word must be `[A-Za-z0-9_-]+`, not contain `=`, and be in `ALLOWED_PROGRAMS` (`bat`, `cargo`; `rust/demo-emit/tests/committed.rs` keeps this equal to the first words of the committed rows). It is resolved in the absolute entries of `PATH` only, never the working directory.

## What the emitter checks

| Code | Refuses |
|---|---|
| E-INPUT | no rows, no `env`, unreadable directory, bad root |
| E-ID | a row file whose id is not `[a-z0-9]+` (bytes, no locale) |
| E-ROWS | a file not in `rows.list`, a listed file missing, a sha256 pin that differs, a malformed or duplicate pin line, any other entry in the directory |
| E-EMPTY / E-FORM | an empty command file / a line outside the closed form |
| E-CWD | a `<id>.cwd` that is not one relative path of `[A-Za-z0-9_.-]` components naming a directory that stays inside the checkout (symlinks resolved) |
| E-ENV | an `env` key outside the closed list, a duplicate, a non-printable value, a relative `CARGO_TARGET_DIR` |
| E-WARM | the unrecorded warm-up (`cargo test --no-run`, `cargo build --examples`, in `rust/ads-rust`) failing |
| E-SPAWN / E-STATUS / E-TIMEOUT | a program that cannot start / a non-zero exit or death by signal (the real status, never 0) / a command past `--timeout-s` (the whole process group is killed). The first one stops the session. |
| E-UTF8 | output that is not UTF-8 |
| E-TESTS | a `cargo test` command with no `test result:` line, a failed or ignored test, or passed == 0 |
| E-LEAK | a host path, or a hex run of 16 or more digits that is not exactly sixteen or forty zeros, left after normalisation |
| E-OUT | `OUT.json` cannot be written (it is written to `OUT.json.tmp` and renamed only after every row passed) |

## The session environment

Each command runs with a cleared environment: the keys of `term-demos/env` (a closed list), plus `HOME` (a scratch directory), `PATH` (absolute entries of the caller's), `CARGO_HOME`, `RUSTUP_HOME`, `CARGO_TARGET_DIR` (absolute), `LC_ALL=C`, `TZ=UTC`, and `GIT_CONFIG_NOSYSTEM`, `GIT_CONFIG_GLOBAL=/dev/null` and a `safe.directory` entry for the checkout. Nothing else is inherited. Stdin is null; stdout and stderr share one ordered pipe.

## Normalisation

Checkout and target spellings (logical and physical) become `.` and `target`; cargo status lines are dropped; `-<16 hex>` at the end of a `target/...` path becomes sixteen zeros; ` in 12.34s` becomes ` in 0.00s`; `commit=<40 hex>` and the bench `polars:` / `btreemap:` timings are pinned. Then the leak scan runs over the whole transcript.

## Tests

`cargo test --locked --offline --manifest-path rust/demo-emit/Cargo.toml` (or `make rust-demo-test`). Every evasion named in the review verdicts and every error code is a named test; the binary is driven end to end with fake `bat` and `cargo`; `tests/committed.rs` validates the 18 committed rows.
