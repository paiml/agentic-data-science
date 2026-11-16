//! Staged demo for lesson m4-02: the wine validation source lines, then the real test run.
use ads_rust::staged::{child, code, pause, show, stage};
use std::io::stdout;

fn main() {
    let o = &mut stdout();
    std::process::exit(code((|| {
        show(
            o,
            "src/p4.rs",
            include_str!("../../src/p4.rs"),
            53,
            65,
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
                "p4",
            ],
        )
    })()));
}
