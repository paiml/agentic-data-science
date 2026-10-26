//! P2: ordinary least squares of body mass on flipper length with aprender.
use aprender::linear_model::LinearRegression;
use aprender::primitives::{Matrix, Vector};
use aprender::traits::Estimator;
use polars::prelude::*;
use serde_json::Value;

/// A fitted line `y = intercept + slope * x`.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Line {
    pub intercept: f64,
    pub slope: f64,
}

/// Flipper length (x) and body mass (y) as plain vectors.
pub fn columns(
    df: &DataFrame,
) -> PolarsResult<(Vec<f64>, Vec<f64>)> {
    let col = |n: &str| -> PolarsResult<Vec<f64>> {
        let c = df.column(n)?.f64()?;
        match c.null_count() {
            0 => Ok(c.into_no_null_iter().collect()),
            k => Err(polars_err!(
                ComputeError: "column {n} has {k} nulls"
            )),
        }
    };
    Ok((col("flipper_length_mm")?, col("body_mass_g")?))
}

fn mean(v: &[f64]) -> f64 {
    v.iter().sum::<f64>() / v.len().max(1) as f64
}

/// Fit y on x with aprender's `LinearRegression`.
///
/// aprender fits in f32, so both columns are centred first (a
/// well-conditioned problem) and the intercept is recovered in f64.
pub fn fit_line(
    x: &[f64],
    y: &[f64],
) -> Result<Line, Box<dyn std::error::Error>> {
    let (mx, my) = (mean(x), mean(y));
    let xs: Vec<f32> = x.iter().map(|v| (v - mx) as f32).collect();
    let ys: Vec<f32> = y.iter().map(|v| (v - my) as f32).collect();
    let m = Matrix::from_vec(xs.len(), 1, xs)?;
    let mut model = LinearRegression::new();
    model.fit(&m, &Vector::from_vec(ys))?;
    let slope = f64::from(model.coefficients()[0]);
    Ok(Line {
        intercept: my - slope * mx,
        slope,
    })
}

/// The golden OLS line from `datasets/golden/p2.json`.
pub fn golden(
    path: &str,
) -> Result<Line, Box<dyn std::error::Error>> {
    let text = std::fs::read_to_string(path)?;
    let v: Value = serde_json::from_str(&text)?;
    let num =
        |k: &str| v["ols"][k].as_f64().ok_or(format!("no ols.{k}"));
    Ok(Line {
        intercept: num("intercept")?,
        slope: num("slope")?,
    })
}

/// The largest absolute difference between the two coefficients.
pub fn max_diff(a: &Line, b: &Line) -> f64 {
    (a.intercept - b.intercept)
        .abs()
        .max((a.slope - b.slope).abs())
}

/// True when both coefficients agree within the absolute tolerance.
pub fn agrees(a: &Line, b: &Line, atol: f64) -> bool {
    max_diff(a, b) <= atol
}
