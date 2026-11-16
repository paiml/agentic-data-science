# Rust native demo batches

One row per terminal scene for Course A (Rust), pipe-separated, twelve fields:
`idx|name|example|source file|from|to|RUN|WAIT|emphasis pattern 1|emphasis pattern 2|narration 1|narration 2`.

`RUN` empty means `cargo run --locked --offline --example <example>`. Test rows run
`cargo test --locked --offline --test pN` with no test-name filter, so the typed line stays inside the
native form (`cargo (run|test) --locked --offline (--example|--test) NAME`). `WAIT` is the text the
scene waits for before the verdict; it must be non-empty and occur in the row's output (an empty WAIT is refused).

`source file` is relative to `rust/ads-rust`, and `from`..`to` (1-based, inclusive) is the whole item the
narration describes: a function with its doc comment, a test function, or the contract block of an example
`main`. Both emphasis patterns are literal text (`.` is any character; `\(`, `\[`, `\*`, `\+` are the literal
character) and each must match a line inside `from`..`to`. `cargo test` of `demo-emit` (`tests/committed.rs`)
refuses a row whose range falls outside its file, whose patterns are absent from the range, or whose pattern
uses any other regex construct.

## Gate rows

A gate row is the one non-cargo form: its `RUN` is exactly `cd "${ADS_ROOT:?}" && make gate-NAME`, because the
gate is a make target (the SHACL check through Jena, the Rust gate script), not a cargo command. Its
`source file` is relative to the repository root (`ontology/shapes/example.shape.ttl`, `scripts/gate-rust.sh`),
not to `rust/ads-rust`. No other `RUN` form is allowed: no `&&` chain of cargo commands, no other program.

## Staged rows

A staged row types ONE command that prints the source lines the narration describes under a
`== source: FILE RANGE ==` header, waits for one typed line (`run`), then prints the live result under a
`== run ==` header. Its `RUN` is exactly `cargo run -q --locked --offline --example NAME`, where `NAME` is a
staged example of `rust/ads-rust` (`[[example]]` in its `Cargo.toml`), or, for the staged gate row,
`cd "${ADS_ROOT:?}" && make shacl-check`. `source file`, `from`..`to` and both emphasis patterns keep the rules
above (the staged gate row resolves from the repository root, like every gate row).

Each staged row has one row in `rust/term-demos` that types the same thing: `cd rust/ads-rust`, the `RUN`, `run`
(the gate row: `make shacl-check`, `run`). `demo.json` lists exactly those typed lines as `commands`, and its
`stdout` shows `run` where a terminal echoes it: directly above the `== run` header. `tests/committed.rs`
refuses a staged `RUN` that no committed row types, a committed staged row no batch row names, and a staged
example that is not in the crate.

A staged row whose `WAIT` contains `test result:` is a staged test row: the emitter holds its run stage to the
rule of a plain `cargo test` line (a result line, no failed or ignored test, at least one passed), and refuses
a staged `cargo` command that is the `RUN` of no batch row.
