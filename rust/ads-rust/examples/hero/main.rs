//! Writes the Anscombe hero image from the landed languages' plots (ADS-DEMO-001 R-9).
//!
//! Provable contract: the hero names every landed language; missing plot = failure.
//! usage: hero <artifacts-dir> <landed-file> <out.svg>
use ads_rust::hero::from_dir;

fn main() {
    let a: Vec<String> = std::env::args().collect();
    let landed =
        std::fs::read_to_string(&a[2]).expect("landed file");
    let svg = from_dir(&a[1], &landed).expect("hero");
    assert!(
        landed.lines().all(|l| l.is_empty() || svg.contains(l))
    );
    std::fs::write(&a[3], svg).expect("hero.svg");
    println!(
        "contract: ads-rust-hero-v1 every landed language drawn OK"
    );
}
