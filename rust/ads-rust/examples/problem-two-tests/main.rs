//! Staged demo for lesson m2-03: the problem-two tests' source lines, then the real test run.
use ads_rust::staged::{child, code, pause, show, stage};
use std::io::stdout;

fn main() {
    let o = &mut stdout();
    std::process::exit(code((|| {
        show(
            o,
            "tests/p2.rs",
            include_str!("../../tests/p2.rs"),
            43,
            58,
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
