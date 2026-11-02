# Rust native demo batches

One row per terminal scene for Course A (Rust), pipe-separated:
`idx|name|example|source file|from|to|RUN|WAIT|emphasis pattern 1|emphasis pattern 2|narration 1|narration 2`.

`RUN` empty means `cargo run --locked --offline --example <example>`. Test rows run
`cargo test --locked --offline --test pN` with no test-name filter, so the typed line stays inside the
native form (`cargo (run|test) --locked --offline (--example|--test) NAME`). `WAIT` is the text the
scene waits for before the verdict.
