//! A-M1-P1: ingest Palmer Penguins, apply the NA policy, print the row counts before and after.
//!
//! Provable contract: ads-rust-p1-v1 (344 rows loaded, 342 kept).
use ads_rust::p1::{na_policy, read_penguins};

fn main() {
    let root = std::env::var("ADS_ROOT").unwrap_or_else(|_| {
        format!("{}/../..", env!("CARGO_MANIFEST_DIR"))
    });
    let raw = read_penguins(&format!(
        "{root}/datasets/penguins/penguins.csv"
    ))
    .expect("load");
    let kept = na_policy(raw.clone()).expect("policy");
    println!("rows loaded: {}", raw.height());
    println!("rows kept:   {}", kept.height());
    assert_eq!((raw.height(), kept.height()), (344, 342));
    println!("contract: ads-rust-p1-v1 rows 344 -> 342 OK");
}
