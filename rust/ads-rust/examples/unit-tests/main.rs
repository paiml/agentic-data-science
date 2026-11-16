//! Staged demo for lesson m1-03: the unit tests' source lines, the real test run, the contract line.
use ads_rust::staged::{
    child, code, p1_contract, pause, root, show, stage,
};
use std::io::stdout;

fn main() {
    let o = &mut stdout();
    std::process::exit(code((|| {
        show(
            o,
            "tests/p1.rs",
            include_str!("../../tests/p1.rs"),
            31,
            46,
        )?;
        pause(o, &mut std::io::stdin().lock())?;
        stage(o, "run")?;
        if !child(
            o,
            "cargo",
            &[
                "test",
                "-q",
                "--locked",
                "--offline",
                "--test",
                "p1",
            ],
        )? {
            return Ok(false);
        }
        stage(o, "contract")?;
        p1_contract(o, &root()).map(|()| true)
    })()));
}
