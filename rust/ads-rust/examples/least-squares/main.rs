//! Staged demo for lesson m2-01: the OLS example's source lines, then its live result.
use ads_rust::staged::{
    code, ols_result, pause, root, show, stage,
};
use std::io::stdout;

fn main() {
    let o = &mut stdout();
    std::process::exit(code((|| {
        show(
            o,
            "examples/a-m2-p2-ols/main.rs",
            include_str!("../a-m2-p2-ols/main.rs"),
            41,
            54,
        )?;
        pause(o, &mut std::io::stdin().lock())?;
        stage(o, "run")?;
        ols_result(o, &root()).map(|()| true)
    })()));
}
