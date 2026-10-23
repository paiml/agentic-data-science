//! A-M4-P4a: validate, split, fit and score the Wine Quality pipeline; emit the report artifact.
//!
//! Provable contract: ads-rust-p4-v1 (RMSE within 1e-6 of the golden file; artifact byte-identical).
use ads_rust::p4::{pipeline_wine, report_ttl};

fn main() {
    let root = std::env::var("ADS_ROOT").unwrap_or_else(|_| "../..".into());
    let wine = |c: &str| format!("{root}/datasets/wine-quality/winequality-{c}.csv");
    let res = pipeline_wine(&wine("red"), &wine("white")).expect("pipeline");
    println!("rmse = {:.6}, r2 = {:.6}", res["rmse"], res["r2"]);
    let g: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(format!("{root}/datasets/golden/p4.json")).expect("golden"),
    )
    .expect("parse");
    let d = (res["rmse"].as_f64().expect("rmse") - g["rmse"].as_f64().expect("g")).abs();
    assert!(d <= 1e-6, "diff {d}");
    let ttl =
        std::fs::read_to_string(format!("{root}/datasets/golden/p4-artifact.ttl")).expect("ttl");
    assert_eq!(report_ttl(&res).expect("ttl"), ttl);
    println!("contract: ads-rust-p4-v1 pipeline |rmse diff| = {d:e} OK");
}
