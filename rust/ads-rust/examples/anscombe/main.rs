//! Anscombe's quartet (ADS-DEMO-001 P1): prints the parity report and writes plot.svg.
//!
//! Provable contract: all four sets share mean/slope/intercept/r to 2 decimals; the SVG is written.
use ads_rust::anscombe::{parse, plot_svg, report};

fn main() {
    let root = std::env::var("ADS_ROOT")
        .unwrap_or_else(|_| "../..".into());
    let csv = std::fs::read_to_string(format!(
        "{root}/data/anscombe/anscombe.csv"
    ))
    .expect("data");
    let sets = parse(&csv).expect("parse");
    let text = report(&sets);
    print!("{text}");
    if let Ok(dir) = std::env::var("ADS_OUT") {
        std::fs::write(format!("{dir}/stdout.txt"), &text)
            .expect("stdout.txt");
        std::fs::write(format!("{dir}/plot.svg"), plot_svg(&sets))
            .expect("plot.svg");
    }
    let tails: Vec<&str> = text
        .lines()
        .map(|l| l.split("mean_x=").nth(1).expect("tail"))
        .collect();
    assert!(
        tails.windows(2).all(|w| w[0] == w[1]),
        "the quartet must agree"
    );
    println!(
        "contract: ads-rust-anscombe-v1 four sets, one summary OK"
    );
}
