//! A-M3-P3a: species decision tree on the fixed train/test split.
//!
//! Provable contract: ads-rust-p3-v1 (confusion matrix equals the golden file exactly).
use ads_rust::p1::{na_policy, read_penguins};
use ads_rust::p3::{p3_json, read_centroids, read_split};

fn main() {
    let root = std::env::var("ADS_ROOT").unwrap_or_else(|_| "../..".into());
    let df =
        na_policy(read_penguins(&format!("{root}/datasets/penguins/penguins.csv")).expect("load"))
            .expect("policy");
    let split = read_split(&format!("{root}/datasets/fixtures/split.csv"));
    let cen = read_centroids(&format!("{root}/datasets/fixtures/centroids.csv"));
    let got = p3_json(&df, &split, &cen);
    println!(
        "accuracy:  {}\nconfusion: {}",
        got["accuracy"], got["confusion"]
    );
    let g: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(format!("{root}/datasets/golden/p3.json")).expect("golden"),
    )
    .expect("parse");
    assert_eq!(got["confusion"], g["confusion"]);
    println!("contract: ads-rust-p3-v1 confusion equals golden OK");
}
