//! Staged demo for lesson m3-02: the k-means example's source lines, then its live result.
use ads_rust::staged::{code, pause, root, show_ranges, stage};
use ads_rust::staged_m3m4a::kmeans_result;
use std::io::stdout;

fn main() {
    let o = &mut stdout();
    std::process::exit(code((|| {
        show_ranges(
            o,
            "examples/a-m3-p3-kmeans/main.rs",
            include_str!("../a-m3-p3-kmeans/main.rs"),
            &[(23, 23), (53, 61)],
        )?;
        pause(o, &mut std::io::stdin().lock())?;
        stage(o, "run")?;
        kmeans_result(o, &root()).map(|()| true)
    })()));
}
