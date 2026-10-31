//! P4: Wine Quality pipeline (validate, split, fit, score), report artifact and grouped-mean bench.
use std::collections::BTreeMap;
use std::error::Error;
use std::time::Instant;

use linfa::prelude::*;
use linfa_linear::LinearRegression;
use ndarray::{Array1, Array2};
use polars::prelude::*;
use serde_json::{json, Value};

/// The eleven physico-chemical predictors, in file order.
pub const FEATURES: [&str; 11] = [
    "fixed_acidity",
    "volatile_acidity",
    "citric_acid",
    "residual_sugar",
    "chlorides",
    "free_sulfur_dioxide",
    "total_sulfur_dioxide",
    "density",
    "pH",
    "sulphates",
    "alcohol",
];

/// Read one colour's CSV with typed columns: predictors Float64, quality Int64.
fn read_one(path: &str) -> PolarsResult<DataFrame> {
    let mut schema = Schema::default();
    for f in FEATURES {
        schema.with_column(f.into(), DataType::Float64);
    }
    schema.with_column("quality".into(), DataType::Int64);
    CsvReadOptions::default()
        .with_has_header(true)
        .with_schema_overwrite(Some(Arc::new(schema)))
        .try_into_reader_with_file_path(Some(path.into()))?
        .finish()
}

/// Read and bind the red and white tables (red rows first).
pub fn read_wine(
    red: &str,
    white: &str,
) -> PolarsResult<DataFrame> {
    let mut df = read_one(red)?;
    df.vstack_mut(&read_one(white)?)?;
    Ok(df)
}

/// Stop on a missing value, a quality outside 0..=10, or an unknown colour.
pub fn validate_wine(df: &DataFrame) -> Result<(), Box<dyn Error>> {
    if df.get_columns().iter().any(|c| c.null_count() > 0) {
        return Err("wine data has missing values".into());
    }
    for f in FEATURES {
        if df
            .column(f)?
            .f64()?
            .into_no_null_iter()
            .any(|v| !v.is_finite())
        {
            return Err(format!("non-finite value in {f}").into());
        }
    }
    let q = df.column("quality")?.i64()?;
    if q.into_no_null_iter().any(|v| !(0..=10).contains(&v)) {
        return Err("quality outside 0..10".into());
    }
    let c = df.column("color")?.str()?;
    if c.into_no_null_iter().any(|v| v != "red" && v != "white") {
        return Err("unknown color".into());
    }
    Ok(())
}

/// Deterministic split: every fifth row (1-based) is a test row. Returns (train, test).
pub fn split_wine(
    df: &DataFrame,
) -> PolarsResult<(DataFrame, DataFrame)> {
    let test: BooleanChunked =
        (1..=df.height()).map(|i| i % 5 == 0).collect();
    Ok((df.filter(&!&test)?, df.filter(&test)?))
}

/// Design matrix: the eleven predictors plus a white-colour dummy (red is the baseline).
pub fn design(df: &DataFrame) -> Array2<f64> {
    let mut x = Array2::zeros((df.height(), FEATURES.len() + 1));
    for (j, f) in FEATURES.iter().enumerate() {
        let col =
            df.column(f).expect("feature").f64().expect("f64");
        for (i, v) in col.into_no_null_iter().enumerate() {
            x[[i, j]] = v;
        }
    }
    let color =
        df.column("color").expect("color").str().expect("str");
    for (i, c) in color.into_no_null_iter().enumerate() {
        x[[i, FEATURES.len()]] = f64::from(u8::from(c == "white"));
    }
    x
}

/// Quality as f64.
pub fn target(df: &DataFrame) -> Array1<f64> {
    let q =
        df.column("quality").expect("quality").i64().expect("i64");
    q.into_no_null_iter().map(|v| v as f64).collect()
}

/// (rmse, r2) of predictions against observations.
pub fn metrics(y: &Array1<f64>, pred: &Array1<f64>) -> (f64, f64) {
    let sse = (y - pred).mapv(|e| e * e).sum();
    let sst = (y - y.mean().unwrap_or(0.0)).mapv(|e| e * e).sum();
    ((sse / y.len() as f64).sqrt(), 1.0 - sse / sst)
}

/// Mean quality and row count per colour, hand-rolled over a `BTreeMap`.
pub fn aggregate_map(df: &DataFrame) -> Vec<(String, f64, usize)> {
    let color =
        df.column("color").expect("color").str().expect("str");
    let q =
        df.column("quality").expect("quality").i64().expect("i64");
    let mut acc: BTreeMap<&str, (i64, usize)> = BTreeMap::new();
    for (c, v) in
        color.into_no_null_iter().zip(q.into_no_null_iter())
    {
        let e = acc.entry(c).or_insert((0, 0));
        e.0 += v;
        e.1 += 1;
    }
    acc.into_iter()
        .map(|(c, (s, n))| (c.to_string(), s as f64 / n as f64, n))
        .collect()
}

/// Mean quality and row count per colour with a polars lazy group-by.
pub fn aggregate_polars(
    df: &DataFrame,
) -> PolarsResult<Vec<(String, f64, usize)>> {
    let out = df
        .clone()
        .lazy()
        .group_by([col("color")])
        .agg([
            col("quality")
                .cast(DataType::Float64)
                .mean()
                .alias("m"),
            col("quality").count().alias("n"),
        ])
        .sort(["color"], SortMultipleOptions::default())
        .collect()?;
    let c = out.column("color")?.str()?;
    let m = out.column("m")?.f64()?;
    let n = out.column("n")?.u32()?;
    Ok(c.into_no_null_iter()
        .zip(m.into_no_null_iter().zip(n.into_no_null_iter()))
        .map(|(c, (m, n))| (c.to_string(), m, n as usize))
        .collect())
}

/// Validate, split, fit a linear quality model on train, score it on test.
pub fn pipeline_wine(
    red: &str,
    white: &str,
) -> Result<Value, Box<dyn Error>> {
    let df = read_wine(red, white)?;
    validate_wine(&df)?;
    let (train, test) = split_wine(&df)?;
    let model = LinearRegression::new()
        .fit(&Dataset::new(design(&train), target(&train)))?;
    let pred = model.predict(&design(&test));
    let (rmse, r2) = metrics(&target(&test), &pred);
    let by_color: serde_json::Map<String, Value> =
        aggregate_map(&df)
            .into_iter()
            .map(|(c, m, _)| (c, json!(m)))
            .collect();
    Ok(json!({
        "n_rows": df.height(), "n_train": train.height(), "n_test": test.height(),
        "rmse": rmse, "r2": r2, "mean_quality_by_color": by_color,
    }))
}

/// Median wall time in seconds of the two aggregations over `reps` runs: [(engine, seconds)].
pub fn bench_wine(
    df: &DataFrame,
    reps: usize,
) -> Vec<(&'static str, f64)> {
    fn median(mut v: Vec<f64>) -> f64 {
        v.sort_by(f64::total_cmp);
        v[v.len() / 2]
    }
    let time = |f: &dyn Fn()| {
        median(
            (0..reps.max(1))
                .map(|_| {
                    let t = Instant::now();
                    f();
                    t.elapsed().as_secs_f64()
                })
                .collect(),
        )
    };
    vec![
        ("polars", time(&|| drop(aggregate_polars(df)))),
        ("btreemap", time(&|| drop(aggregate_map(df)))),
    ]
}

/// The pipeline report as an `ads:Artifact` in Turtle (byte-identical to the golden file).
pub fn report_ttl(res: &Value) -> Result<String, Box<dyn Error>> {
    let rmse = res["rmse"]
        .as_f64()
        .ok_or("report needs a numeric rmse")?;
    let rows =
        res["n_rows"].as_u64().ok_or("report needs n_rows")?;
    Ok(format!(
        "@prefix ads: <https://paiml.com/ns/ads#> .\n@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n\n\
         <https://paiml.com/ns/ads#wine-report> a ads:Artifact ;\n  ads:schemaVersion \"1\" ;\n  \
         ads:generatedBy \"agenticds::pipeline_wine\" ;\n  ads:rmse \"{:.10}\"^^xsd:decimal ;\n  \
         ads:rows \"{}\"^^xsd:integer .\n",
        rmse, rows,
    ))
}

/// Reference outputs for the Lean course: the pipeline result as pretty JSON.
pub fn export_oracle(res: &Value) -> String {
    serde_json::to_string_pretty(res).unwrap_or_default() + "\n"
}
