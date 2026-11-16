//! Staged demo for lesson m2-08: the linfa fit and metrics source lines, then its live result.
use ads_rust::staged::{code, cv_result, pause, root, show, stage};
use std::io::stdout;

fn main() {
    let o = &mut stdout();
    std::process::exit(code((|| {
        show(
            o,
            "src/p2.rs",
            include_str!("../../src/p2.rs"),
            67,
            85,
        )?;
        pause(o, &mut std::io::stdin().lock())?;
        stage(o, "run")?;
        cv_result(o, &root()).map(|()| true)
    })()));
}
