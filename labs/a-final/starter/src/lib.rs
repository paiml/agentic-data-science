//! Course A (Rust) end-of-course lab. Replace each `todo!()` using the course library (`ads_rust`).
use ndarray::Array1;

/// Task 1: rows left in the penguins CSV after the course NA policy (typed load, then `na_policy`).
pub fn clean_rows(path: &str) -> usize {
    todo!("read_penguins, then na_policy, then height")
}

/// Task 2: the Adelie mean body mass (g) from the course's per-species summary JSON.
pub fn adelie_mean_mass(path: &str) -> f64 {
    todo!("summary_by_species(..)[\"species\"][\"Adelie\"][\"body_mass_g\"][\"mean\"]")
}

/// Task 3: closed-form simple OLS, returning (intercept, slope).
pub fn fit_line(x: &Array1<f64>, y: &Array1<f64>) -> (f64, f64) {
    todo!("ads_rust::p2::ols_ndarray")
}
