//! A-M4-P4b: polars group-by vs a hand-rolled BTreeMap, same answer, timed.
//!
//! Provable contract: ads-rust-p4-v1 (the two aggregates agree per colour to 1e-12).
use ads_rust::p4::{aggregate_map, aggregate_polars, bench_wine, read_wine};

fn main() {
    let root = std::env::var("ADS_ROOT").unwrap_or_else(|_| "../..".into());
    let wine = |c: &str| format!("{root}/datasets/wine-quality/winequality-{c}.csv");
    let df = read_wine(&wine("red"), &wine("white")).expect("load");
    let (a, b) = (aggregate_polars(&df).expect("polars"), aggregate_map(&df));
    assert_eq!(a.len(), b.len());
    let d = a.iter().zip(&b).map(|(x, y)| {
        assert_eq!((&x.0, x.2), (&y.0, y.2));
        (x.1 - y.1).abs()
    });
    let d = d.fold(0.0, f64::max);
    assert!(d <= 1e-12, "diff {d}");
    for (engine, secs) in bench_wine(&df, 20) {
        println!("{engine:>9}: {:.6} ms", secs * 1e3);
    }
    println!("contract: ads-rust-p4-v1 aggregates max |diff| = {d:e} OK");
}
