//! Staged demo for lesson m2-09: p2_json's source lines, then the real test run.
use ads_rust::staged::{child, code, pause, show, stage};
use std::io::stdout;

fn main() {
    let o = &mut stdout();
    std::process::exit(code((|| {
        show(
            o,
            "src/p2.rs",
            include_str!("../../src/p2.rs"),
            148,
            151,
        )?;
        pause(o, &mut std::io::stdin().lock())?;
        stage(o, "run")?;
        child(
            o,
            "cargo",
            &[
                "test",
                "-q",
                "--locked",
                "--offline",
                "--test",
                "p2",
            ],
        )
    })()));
}
