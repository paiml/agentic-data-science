//! P1: typed load, NA policy and per-species summary of Palmer Penguins.
use polars::prelude::*;
use serde_json::{Map, Value, json};

/// The four numeric measurement columns, in golden-file order.
pub const MEASURES: [&str; 4] = [
    "bill_length_mm",
    "bill_depth_mm",
    "flipper_length_mm",
    "body_mass_g",
];

/// Typed load: "NA" is null; the measurements are Float64.
pub fn read_penguins(path: &str) -> PolarsResult<DataFrame> {
    let mut schema = Schema::default();
    for m in MEASURES {
        schema.with_column(m.into(), DataType::Float64);
    }
    let opts = CsvReadOptions::default()
        .with_has_header(true)
        .with_schema_overwrite(Some(Arc::new(schema)))
        .with_parse_options(
            CsvParseOptions::default().with_null_values(Some(
                NullValues::AllColumnsSingle("NA".into()),
            )),
        );
    opts.try_into_reader_with_file_path(Some(path.into()))?
        .finish()
}

/// NA policy: drop a row iff any numeric measurement is null (an NA in `sex` alone keeps it).
pub fn na_policy(df: DataFrame) -> PolarsResult<DataFrame> {
    let keep = MEASURES
        .iter()
        .fold(lit(true), |acc, m| acc.and(col(*m).is_not_null()));
    df.lazy().filter(keep).collect()
}

/// Per-species n, mean and sample SD (n-1 denominator) as the golden JSON shape.
pub fn summary_by_species(df: DataFrame) -> PolarsResult<Value> {
    let mut aggs = vec![col("species").count().alias("n")];
    for m in MEASURES {
        aggs.push(col(m).mean().alias(format!("{m}_mean")));
        aggs.push(col(m).std(1).alias(format!("{m}_sd")));
    }
    let g = df
        .lazy()
        .group_by([col("species")])
        .agg(aggs)
        .sort(["species"], SortMultipleOptions::default())
        .collect()?;
    let names = g.column("species")?.str()?;
    let mut species = Map::new();
    for i in 0..g.height() {
        let mut o = Map::new();
        o.insert("n".into(), json!(f64_at(&g, "n", i)?));
        for m in MEASURES {
            let mean = f64_at(&g, &format!("{m}_mean"), i)?;
            let sd = f64_at(&g, &format!("{m}_sd"), i)?;
            o.insert(m.into(), json!({"mean": mean, "sd": sd}));
        }
        species.insert(
            names.get(i).unwrap_or_default().to_string(),
            Value::Object(o),
        );
    }
    Ok(json!({ "species": species }))
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
