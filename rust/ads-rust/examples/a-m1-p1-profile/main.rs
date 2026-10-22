//! A-M1-P1b: per-species profile as JSON, checked against the golden file.
//!
//! Provable contract: ads-rust-p1-v1 (|computed - golden| <= 1e-9).
use ads_rust::p1::{max_abs_diff, na_policy, read_penguins, summary_by_species};

fn main() {
    let root = std::env::var("ADS_ROOT").unwrap_or_else(|_| "../..".into());
    let df =
        na_policy(read_penguins(&format!("{root}/datasets/penguins/penguins.csv")).expect("load"))
            .expect("policy");
    let s = summary_by_species(df).expect("summary");
    println!("{}", serde_json::to_string_pretty(&s).expect("json"));
    let golden: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(format!("{root}/datasets/golden/p1.json")).expect("golden"),
    )
    .expect("parse");
    let d = max_abs_diff(&s, &golden);
    assert!(d <= 1e-9, "diff {d}");
    println!("contract: ads-rust-p1-v1 max |diff| = {d:e} OK");
}
