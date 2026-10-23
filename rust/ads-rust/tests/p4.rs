use ads_rust::p4::*;
use linfa::prelude::*;
use linfa_linear::LinearRegression;
use polars::prelude::*;
use serde_json::{json, Value};

const ROOT: &str = "../..";

fn wine(c: &str) -> String {
    format!("{ROOT}/datasets/wine-quality/winequality-{c}.csv")
}
fn golden() -> Value {
    serde_json::from_str(
        &std::fs::read_to_string(format!("{ROOT}/datasets/golden/p4.json")).unwrap(),
    )
    .unwrap()
}
fn frame() -> DataFrame {
    read_wine(&wine("red"), &wine("white")).unwrap()
}

#[test]
fn pipeline_matches_golden() {
    let got = pipeline_wine(&wine("red"), &wine("white")).unwrap();
    let want = golden();
    for k in ["n_rows", "n_train", "n_test"] {
        assert_eq!(got[k], want[k], "{k}");
    }
    for k in ["rmse", "r2"] {
        assert!(
            (got[k].as_f64().unwrap() - want[k].as_f64().unwrap()).abs() <= 1e-6,
            "{k}"
        );
    }
    for c in ["red", "white"] {
        let (a, b) = (
            &got["mean_quality_by_color"][c],
            &want["mean_quality_by_color"][c],
        );
        assert!(
            (a.as_f64().unwrap() - b.as_f64().unwrap()).abs() <= 1e-9,
            "{c}"
        );
    }
}

#[test]
fn can_fail_when_the_model_sees_the_test_rows() {
    // Mutant: fit on all rows. Held-out RMSE leaves the golden by more than the tolerance.
    let df = frame();
    let (_, test) = split_wine(&df).unwrap();
    let m = LinearRegression::new()
        .fit(&Dataset::new(design(&df), target(&df)))
        .unwrap();
    let (rmse, _) = metrics(&target(&test), &m.predict(&design(&test)));
    assert!((rmse - golden()["rmse"].as_f64().unwrap()).abs() > 1e-4);
}

#[test]
fn read_split_and_validate() {
    let df = frame();
    assert_eq!(df.height(), 6497);
    validate_wine(&df).unwrap();
    let (train, test) = split_wine(&df).unwrap();
    assert_eq!((train.height(), test.height()), (5198, 1299));
    // Every fifth row (1-based) is a test row: row 5 is the first.
    let alc = |d: &DataFrame, i: usize| d.column("alcohol").unwrap().f64().unwrap().get(i).unwrap();
    assert_eq!(alc(&test, 0), alc(&df, 4));
    assert!(read_wine("no/such/red.csv", &wine("white")).is_err());
}

#[test]
fn validate_rejects_each_defect() {
    let df = frame();
    let n = df.height();
    let mut nulled = df.clone();
    let alc: Vec<Option<f64>> = (0..n).map(|i| (i != 0).then_some(1.0)).collect();
    nulled
        .replace("alcohol", Series::new("alcohol".into(), alc))
        .unwrap();
    assert!(validate_wine(&nulled)
        .unwrap_err()
        .to_string()
        .contains("missing"));
    let mut bad_q = df.clone();
    let q: Vec<i64> = (0..n).map(|i| if i == 0 { 11 } else { 5 }).collect();
    bad_q
        .replace("quality", Series::new("quality".into(), q))
        .unwrap();
    assert!(validate_wine(&bad_q)
        .unwrap_err()
        .to_string()
        .contains("quality"));
    let mut bad_c = df.clone();
    let c: Vec<&str> = (0..n)
        .map(|i| if i == 0 { "rose" } else { "red" })
        .collect();
    bad_c
        .replace("color", Series::new("color".into(), c))
        .unwrap();
    assert!(validate_wine(&bad_c)
        .unwrap_err()
        .to_string()
        .contains("color"));
    // Range edges: -1 and 11 are out, 0 and 10 are in.
    for (q0, ok) in [(-1, false), (0, true), (10, true), (11, false)] {
        let mut d = df.clone();
        let q: Vec<i64> = (0..n).map(|i| if i == 0 { q0 } else { 5 }).collect();
        d.replace("quality", Series::new("quality".into(), q))
            .unwrap();
        assert_eq!(validate_wine(&d).is_ok(), ok, "quality {q0}");
    }
    // Non-finite predictors and missing predictor columns are errors, not panics.
    let mut inf = df.clone();
    let a: Vec<f64> = (0..n)
        .map(|i| if i == 0 { f64::INFINITY } else { 1.0 })
        .collect();
    inf.replace("alcohol", Series::new("alcohol".into(), a))
        .unwrap();
    assert!(validate_wine(&inf)
        .unwrap_err()
        .to_string()
        .contains("alcohol"));
    assert!(validate_wine(&df.drop("alcohol").unwrap()).is_err());
    // Missing columns surface as errors, not panics.
    assert!(validate_wine(&df.drop("quality").unwrap()).is_err());
    assert!(validate_wine(&df.drop("color").unwrap()).is_err());
}

#[test]
fn pipeline_stops_on_a_bad_file() {
    let dir = std::env::temp_dir().join("ads-rust-p4-bad");
    std::fs::create_dir_all(&dir).unwrap();
    let bad = dir.join("bad.csv");
    let mut text = std::fs::read_to_string(wine("red")).unwrap();
    text.push_str("7.4,0.7,0,1.9,0.076,11,34,0.9978,3.51,0.56,9.4,11,red\n");
    std::fs::write(&bad, text).unwrap();
    let e = pipeline_wine(bad.to_str().unwrap(), &wine("white")).unwrap_err();
    assert!(e.to_string().contains("quality"));
    assert!(pipeline_wine("no/such.csv", &wine("white")).is_err());
}

#[test]
fn aggregates_agree_and_bench_times_both() {
    let df = frame();
    let (a, b) = (aggregate_polars(&df).unwrap(), aggregate_map(&df));
    assert_eq!(a.len(), 2);
    for (x, y) in a.iter().zip(&b) {
        assert_eq!((&x.0, x.2), (&y.0, y.2));
        assert!((x.1 - y.1).abs() <= 1e-12);
    }
    assert_eq!((b[0].0.as_str(), b[0].2, b[1].2), ("red", 1599, 4898));
    assert_eq!(bench_wine(&df, 0).len(), 2);
    let t = bench_wine(&df, 3);
    assert_eq!(
        t.iter().map(|e| e.0).collect::<Vec<_>>(),
        ["polars", "btreemap"]
    );
    assert!(t.iter().all(|e| e.1 >= 0.0));
}

#[test]
fn report_and_oracle_round_trip() {
    let res = pipeline_wine(&wine("red"), &wine("white")).unwrap();
    let ttl = std::fs::read_to_string(format!("{ROOT}/datasets/golden/p4-artifact.ttl")).unwrap();
    assert_eq!(report_ttl(&res).unwrap(), ttl);
    let back: Value = serde_json::from_str(&export_oracle(&res)).unwrap();
    assert_eq!(back, res);
    // A result with no rmse or no row count is refused, never written as a fake artifact.
    assert!(report_ttl(&json!({})).is_err());
    assert!(report_ttl(&json!({"rmse": 0.5})).is_err());
    // No timing keys ever reach the golden file or the oracle.
    for k in ["seconds", "time", "ms", "bench"] {
        assert!(golden().get(k).is_none() && back.get(k).is_none());
    }
}
