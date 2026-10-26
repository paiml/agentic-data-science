//! A-M2-P2: OLS of body mass on flipper length.
use ads_rust::{p1, p2, show};

fn main() {
    let csv = show::data_path("penguins/penguins.csv");
    // Load the CSV and apply the NA policy.
    let raw = p1::read_penguins(&csv).expect("load");
    let df = p1::na_policy(raw).expect("policy");
    show::rows("rows used", df.height());

    // Fit body mass on flipper length with aprender.
    let (x, y) = p2::columns(&df).expect("columns");
    let fit = p2::fit_line(&x, &y).expect("fit");
    show::line(&fit);

    // Species scatter and the fit, in the terminal.
    show::chart(&df, &fit).expect("chart");

    // Compare with the golden line (atol 1e-2).
    let path = show::data_path("golden/p2.json");
    let gold = p2::golden(&path).expect("golden");
    assert!(p2::agrees(&fit, &gold, 1e-2));
    show::agreement(p2::max_diff(&fit, &gold), 1e-2);
}
