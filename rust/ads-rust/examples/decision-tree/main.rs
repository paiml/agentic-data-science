//! Staged demo for lesson m3-01: the tree example's source lines, then its live result.
use ads_rust::staged::{
    code, p3_result, pause, root, show_ranges, stage,
};
use std::io::stdout;

fn main() {
    let o = &mut stdout();
    std::process::exit(code((|| {
        show_ranges(
            o,
            "examples/a-m3-p3-tree/main.rs",
            include_str!("../a-m3-p3-tree/main.rs"),
            &[(23, 23), (44, 51)],
        )?;
        pause(o, &mut std::io::stdin().lock())?;
        stage(o, "run")?;
        p3_result(o, &root()).map(|()| true)
    })()));
}
