//! Staged demo for lesson m1-01: the first example's source lines, then its live result.
use ads_rust::staged::{code, p1_counts, pause, root, show, stage};
use std::io::stdout;

fn main() {
    let o = &mut stdout();
    std::process::exit(code((|| {
        show(
            o,
            "examples/a-m1-p1/main.rs",
            include_str!("../a-m1-p1/main.rs"),
            9,
            16,
        )?;
        pause(o, &mut std::io::stdin().lock())?;
        stage(o, "run")?;
        p1_counts(o, &root()).map(|()| true)
    })()));
}
