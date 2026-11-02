//! Lab (Course A, Module 1) P1: typed load, NA policy and per-species summary of Palmer Penguins.
use polars::prelude::*;
use serde_json::{json, Map, Value};

/// The four numeric measurement columns, in golden-file order.
pub const MEASURES: [&str; 4] = [
    "bill_length_mm",
    "bill_depth_mm",
    "flipper_length_mm",
    "body_mass_g",
];

/// Typed load: "NA" is null; the measurements are Float64.
pub fn read_penguins(path: &str) -> PolarsResult<DataFrame> {
    // TODO 1: read the CSV with "NA" as null and the four MEASURES columns as Float64.
    let _ = path;
    todo!("read_penguins")
}

/// NA policy: drop a row iff any numeric measurement is null (an NA in `sex` alone keeps it).
pub fn na_policy(df: DataFrame) -> PolarsResult<DataFrame> {
    // TODO 2: drop a row iff any MEASURES column is null (a null `sex` alone keeps the row).
    let _ = df;
    todo!("na_policy")
}

/// Per-species n, mean and sample SD (n-1 denominator) as the golden JSON shape.
pub fn summary_by_species(df: DataFrame) -> PolarsResult<Value> {
    // TODO 3: per species n, mean and sample SD (n-1) of each measure, as {"species": {name: {n, <measure>: {mean, sd}}}}.
    // Helper provided below: f64_at(&df, column, row).
    let _ = df;
    todo!("summary_by_species")
}

/// Largest absolute difference between two summaries' numeric leaves (`f64::INFINITY` on a shape mismatch).
pub fn max_abs_diff(a: &Value, b: &Value) -> f64 {
    match (a, b) {
        (Value::Number(x), Value::Number(y)) => {
            (x.as_f64().unwrap_or(f64::NAN)
                - y.as_f64().unwrap_or(f64::NAN))
            .abs()
        }
        (Value::Object(x), Value::Object(y))
            if x.len() == y.len() =>
        {
            x.iter()
                .map(|(k, v)| {
                    y.get(k).map_or(f64::INFINITY, |w| {
                        max_abs_diff(v, w)
                    })
                })
                .fold(0.0, f64::max)
        }
        _ => f64::INFINITY,
    }
}

/// Cell `i` of column `name` as f64 (one shared error path for every aggregate lookup).
fn f64_at(
    g: &DataFrame,
    name: &str,
    i: usize,
) -> PolarsResult<f64> {
    Ok(g.column(name)?
        .cast(&DataType::Float64)?
        .f64()?
        .get(i)
        .unwrap_or(f64::NAN))
}
