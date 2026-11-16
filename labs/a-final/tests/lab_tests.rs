//! Shared lab suite. Expected values come from datasets/golden/p1.json (Adelie n=151 + Chinstrap 68 + Gentoo 123 = 342).
use lab_a_final::*;
use ndarray::array;

fn penguins() -> String {
    format!("{}/../../../datasets/penguins/penguins.csv", env!("CARGO_MANIFEST_DIR"))
}

#[test]
fn lab_t1_clean_rows() {
    assert_eq!(clean_rows(&penguins()), 342);
}

#[test]
fn lab_t2_adelie_mean_mass() {
    assert!((adelie_mean_mass(&penguins()) - 3700.66225165563).abs() < 1e-6);
}

#[test]
fn lab_t3_fit_line() {
    let (a, b) = fit_line(&array![1.0, 2.0, 3.0, 4.0], &array![3.0, 5.0, 7.0, 9.0]);
    assert!((a - 1.0).abs() < 1e-9 && (b - 2.0).abs() < 1e-9, "got ({a}, {b})");
}
