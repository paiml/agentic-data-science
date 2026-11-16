//! Staged demo for lesson m2-02: the cross-validation example's source lines, then its live result.
use ads_rust::staged::{code, cv_result, pause, root, show, stage};
use std::io::stdout;

fn main() {
    let o = &mut stdout();
    std::process::exit(code((|| {
        show(
            o,
            "examples/a-m2-p2-cv/main.rs",
            include_str!("../a-m2-p2-cv/main.rs"),
            48,
            64,
        )?;
        pause(o, &mut std::io::stdin().lock())?;
        stage(o, "run")?;
        cv_result(o, &root()).map(|()| true)
    })()));
}
