//! Staged demo for lesson m4-01: the pipeline example's source lines, then its live result.
use ads_rust::staged::{code, pause, root, show_ranges, stage};
use ads_rust::staged_m3m4a::pipeline_result;
use std::io::stdout;

fn main() {
    let o = &mut stdout();
    std::process::exit(code((|| {
        show_ranges(
            o,
            "examples/a-m4-p4-pipeline/main.rs",
            include_str!("../a-m4-p4-pipeline/main.rs"),
            &[(12, 13), (35, 43)],
        )?;
        pause(o, &mut std::io::stdin().lock())?;
        stage(o, "run")?;
        pipeline_result(o, &root()).map(|()| true)
    })()));
}
