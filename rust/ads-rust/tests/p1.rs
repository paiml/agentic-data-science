use ads_rust::p1::*;
use serde_json::Value;

const CSV: &str = "../../datasets/penguins/penguins.csv";
const GOLDEN: &str = "../../datasets/golden/p1.json";

fn golden() -> Value {
    serde_json::from_str(&std::fs::read_to_string(GOLDEN).unwrap())
        .unwrap()
}

#[test]
fn load_is_typed_and_has_344_rows() {
    let df = read_penguins(CSV).unwrap();
    assert_eq!(df.height(), 344);
    assert_eq!(
        df.column("body_mass_g").unwrap().dtype(),
        &polars::prelude::DataType::Float64
    );
}

#[test]
fn na_policy_keeps_342_and_keeps_sex_only_na_rows() {
    let df = read_penguins(CSV).unwrap();
    let kept = na_policy(df.clone()).unwrap();
    assert_eq!(kept.height(), 342);
    // 11 rows have NA sex; the 2 dropped rows are the only all-NA-measure rows, so 9 NA-sex rows stay.
    assert_eq!(kept.column("sex").unwrap().null_count(), 9);
}

#[test]
fn summary_matches_golden_within_1e_9() {
    let s = summary_by_species(
        na_policy(read_penguins(CSV).unwrap()).unwrap(),
    )
    .unwrap();
    assert!(max_abs_diff(&s, &golden()) <= 1e-9);
}

#[test]
fn can_fail_without_the_na_policy() {
    // Mutant: skip the policy. Counts change (344 rows -> Adelie n=152), so the golden comparison must fail.
    let s =
        summary_by_species(read_penguins(CSV).unwrap()).unwrap();
    assert!(max_abs_diff(&s, &golden()) > 1e-9);
}

#[test]
fn max_abs_diff_refuses_shape_mismatch() {
    let a: Value = serde_json::json!({"x": 1.0});
    assert!(max_abs_diff(&a, &serde_json::json!({"y": 1.0}))
        .is_infinite());
    assert!(max_abs_diff(
        &a,
        &serde_json::json!({"x": 1.5, "z": 0})
    )
    .is_infinite());
    assert!(max_abs_diff(&a, &serde_json::json!(3)).is_infinite());
    let d = max_abs_diff(&a, &serde_json::json!({"x": 1.5}));
    assert!((d - 0.5).abs() < 1e-12, "{d}");
}

#[test]
fn errors_propagate_instead_of_panicking() {
    assert!(read_penguins("no/such/file.csv").is_err());
    let empty = polars::prelude::DataFrame::empty();
    assert!(na_policy(empty.clone()).is_err());
    assert!(summary_by_species(empty).is_err());
}
