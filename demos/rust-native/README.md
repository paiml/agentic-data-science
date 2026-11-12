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
