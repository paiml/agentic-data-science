//! Course A (Rust) end-of-course lab: reference solution.
use ads_rust::{p1, p2};
use ndarray::Array1;

/// Task 1: rows left in the penguins CSV after the course NA policy.
pub fn clean_rows(path: &str) -> usize {
    let df = p1::read_penguins(path).expect("read");
    p1::na_policy(df).expect("na policy").height()
}

/// Task 2: the Adelie mean body mass (g).
pub fn adelie_mean_mass(path: &str) -> f64 {
    let df = p1::na_policy(p1::read_penguins(path).expect("read")).expect("na policy");
    let v = p1::summary_by_species(df).expect("summary");
    v["species"]["Adelie"]["body_mass_g"]["mean"]
        .as_f64()
        .expect("mean")
}

/// Task 3: closed-form simple OLS, returning (intercept, slope).
pub fn fit_line(x: &Array1<f64>, y: &Array1<f64>) -> (f64, f64) {
    p2::ols_ndarray(x, y)
}
