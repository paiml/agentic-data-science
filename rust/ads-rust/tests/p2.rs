use ads_rust::p1::{na_policy, read_penguins};
use ads_rust::p2::*;
use serde_json::Value;

const ROOT: &str = "../..";

fn load() -> (Cols, Vec<usize>, Value) {
    let df = na_policy(read_penguins(&format!("{ROOT}/datasets/penguins/penguins.csv")).unwrap())
        .unwrap();
    let folds = read_folds(&format!("{ROOT}/datasets/fixtures/folds.csv"));
    let g = serde_json::from_str(
        &std::fs::read_to_string(format!("{ROOT}/datasets/golden/p2.json")).unwrap(),
    )
    .unwrap();
    (cols(&df), folds, g)
}

/// Max abs difference over the keys of `want`, with a per-section tolerance check.
fn diff(got: &Value, want: &Value, section: &[&str]) -> f64 {
    let (mut g, mut w) = (got, want);
    for k in section {
        g = &g[*k];
        w = &w[*k];
    }
    w.as_object()
        .unwrap()
        .iter()
        .map(|(k, v)| (g[k].as_f64().unwrap() - v.as_f64().unwrap()).abs())
        .fold(0.0, f64::max)
}

#[test]
fn coefficients_match_golden_within_1e_8() {
    let (c, f, want) = load();
    let got = p2_json(&c, &f);
    assert_eq!(f.len(), 342);
    assert!(diff(&got, &want, &["ols"]) <= 1e-8);
    assert!(diff(&got, &want, &["species_model"]) <= 1e-8);
    assert!(diff(&got, &want, &["metrics", "ols"]) <= 1e-8);
    assert!(diff(&got, &want, &["metrics", "species"]) <= 1e-8);
}

#[test]
fn cv_rmse_matches_golden_within_1e_6() {
    let (c, f, want) = load();
    assert!(diff(&p2_json(&c, &f), &want, &["cv_rmse"]) <= 1e-6);
}

#[test]
fn can_fail_when_folds_differ() {
    // Mutant: two folds (row parity) instead of the fixed 5-fold file changes the pooled CV error, so parity must fail.
    let (c, f, want) = load();
    let f: Vec<usize> = (0..f.len()).map(|i| 1 + i % 2).collect();
    assert!(diff(&p2_json(&c, &f), &want, &["cv_rmse"]) > 1e-6);
}

#[test]
fn can_fail_when_species_are_ignored() {
    // Mutant: species model without dummies equals plain OLS, which is not the golden species model.
    let (c, _, want) = load();
    let (b0, b1) = ols_ndarray(&c.flipper, &c.mass);
    assert!((b0 - want["species_model"]["(Intercept)"].as_f64().unwrap()).abs() > 1.0);
    assert!((b1 - want["species_model"]["flipper_length_mm"].as_f64().unwrap()).abs() > 1.0);
}
