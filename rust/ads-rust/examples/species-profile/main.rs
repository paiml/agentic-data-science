//! Staged demo for lesson m1-02: the profile example's source lines, then its live result.
use ads_rust::staged::{
    code, p1_profile, pause, root, show, stage,
};
use std::io::stdout;

fn main() {
    let o = &mut stdout();
    std::process::exit(code((|| {
        show(
            o,
            "examples/a-m1-p1-profile/main.rs",
            include_str!("../a-m1-p1-profile/main.rs"),
            46,
            48,
        )?;
        pause(o, &mut std::io::stdin().lock())?;
        stage(o, "run")?;
        p1_profile(o, &root()).map(|()| true)
    })()));
}
