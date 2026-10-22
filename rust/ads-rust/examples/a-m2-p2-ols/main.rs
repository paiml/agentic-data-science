//! A-M2-P2a: closed-form OLS of body mass on flipper length with ndarray.
//!
//! Provable contract: ads-rust-p2-v1 (intercept and slope within 1e-8 of the golden file).
use ads_rust::p1::{na_policy, read_penguins};
use ads_rust::p2::{cols, ols_ndarray};

fn main() {
    let root = std::env::var("ADS_ROOT").unwrap_or_else(|_| "../..".into());
    let df =
        na_policy(read_penguins(&format!("{root}/datasets/penguins/penguins.csv")).expect("load"))
            .expect("policy");
    let c = cols(&df);
    let (b0, b1) = ols_ndarray(&c.flipper, &c.mass);
    println!("intercept = {b0:.6}, slope = {b1:.6}");
    let g: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(format!("{root}/datasets/golden/p2.json")).expect("golden"),
    )
    .expect("parse");
    let d = (b0 - g["ols"]["intercept"].as_f64().expect("b0"))
        .abs()
        .max((b1 - g["ols"]["slope"].as_f64().expect("b1")).abs());
    assert!(d <= 1e-8, "diff {d}");
    println!("contract: ads-rust-p2-v1 ols max |diff| = {d:e} OK");
}
