//! A-M2-P2b: species model (linfa-linear) and 5-fold CV on the committed fold file.
//!
//! Provable contract: ads-rust-p2-v1 (CV RMSE within 1e-6 of the golden file).
use ads_rust::p1::{na_policy, read_penguins};
use ads_rust::p2::{cols, cv_rmse, read_folds, verdict};

fn main() {
    let root = std::env::var("ADS_ROOT").unwrap_or_else(|_| "../..".into());
    let df =
        na_policy(read_penguins(&format!("{root}/datasets/penguins/penguins.csv")).expect("load"))
            .expect("policy");
    let folds = read_folds(&format!("{root}/datasets/fixtures/folds.csv"));
    let c = cols(&df);
    let (ols, sp) = (cv_rmse(&c, &folds, false), cv_rmse(&c, &folds, true));
    println!("cv_rmse (ols):     {ols:.6}\ncv_rmse (species): {sp:.6}");
    let g: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(format!("{root}/datasets/golden/p2.json")).expect("golden"),
    )
    .expect("parse");
    let d = (ols - g["cv_rmse"]["ols"].as_f64().expect("ols"))
        .abs()
        .max((sp - g["cv_rmse"]["species"].as_f64().expect("sp")).abs());
    assert!(d <= 1e-6, "diff {d}");
    let line = format!("contract: ads-rust-p2-v1 cv max |diff| = {d:e} OK");
    println!(
        "{}",
        verdict(&line, std::io::IsTerminal::is_terminal(&std::io::stdout()))
    );
}
