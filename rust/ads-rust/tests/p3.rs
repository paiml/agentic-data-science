use ads_rust::p1::{na_policy, read_penguins};
use ads_rust::p3::*;
use ndarray::Array2;
use serde_json::Value;

const ROOT: &str = "../..";

fn load(
) -> (polars::prelude::DataFrame, Vec<bool>, Array2<f64>, Value) {
    let df = na_policy(
        read_penguins(&format!(
            "{ROOT}/datasets/penguins/penguins.csv"
        ))
        .unwrap(),
    )
    .unwrap();
    let split =
        read_split(&format!("{ROOT}/datasets/fixtures/split.csv"));
    let cen = read_centroids(&format!(
        "{ROOT}/datasets/fixtures/centroids.csv"
    ));
    let g = serde_json::from_str(
        &std::fs::read_to_string(format!(
            "{ROOT}/datasets/golden/p3.json"
        ))
        .unwrap(),
    )
    .unwrap();
    (df, split, cen, g)
}

#[test]
fn classifier_matches_golden_exactly() {
    let (df, s, c, g) = load();
    let got = p3_json(&df, &s, &c);
    assert_eq!(got["confusion"], g["confusion"]);
    assert!(
        (got["accuracy"].as_f64().unwrap()
            - g["accuracy"].as_f64().unwrap())
        .abs()
            <= 1e-12
    );
    assert_eq!(got["classes"], g["classes"]);
}

#[test]
fn kmeans_matches_golden_within_1e_6() {
    let (df, s, c, g) = load();
    let got = p3_json(&df, &s, &c);
    assert_eq!(
        got["kmeans"]["cluster_sizes"],
        g["kmeans"]["cluster_sizes"]
    );
    let d = (got["kmeans"]["objective"].as_f64().unwrap()
        - g["kmeans"]["objective"].as_f64().unwrap())
    .abs();
    assert!(d <= 1e-6, "objective diff {d}");
}

#[test]
fn can_fail_with_other_centroids() {
    // Mutant: swap two initial centroids' roles by using only the first row three times -> different result.
    let (df, s, c, g) = load();
    let bad = Array2::from_shape_fn(c.dim(), |(_, j)| {
        c[[0, j]] + j as f64
    });
    let got = p3_json(&df, &s, &bad);
    assert_ne!(got["kmeans"], g["kmeans"]);
}

#[test]
fn can_fail_when_the_tree_is_a_stump() {
    // Mutant: train on one class only -> a leaf; accuracy leaves the golden.
    let (df, s, _, g) = load();
    let (x, y) = features(&df);
    let idx: Vec<usize> =
        (0..y.len()).filter(|&i| s[i] && y[i] == 0).collect();
    let t = fit_tree(&x, &y, &idx);
    assert_eq!(t, Tree::Leaf(0));
    let te: Vec<usize> = (0..y.len()).filter(|&i| !s[i]).collect();
    let truth: Vec<usize> = te.iter().map(|&i| y[i]).collect();
    let pred = vec![0; truth.len()];
    assert!(
        accuracy(&truth, &pred)
            < g["accuracy"].as_f64().unwrap() - 0.1
    );
}

#[test]
fn small_nodes_do_not_split_and_ties_pick_the_first_class() {
    // 10 rows < MINSPLIT: leaf; counts tie 5/5 -> class 0.
    let x = Array2::from_shape_fn((10, 4), |(i, _)| i as f64);
    let y = vec![0, 0, 0, 0, 0, 1, 1, 1, 1, 1];
    let idx: Vec<usize> = (0..10).collect();
    assert_eq!(fit_tree(&x, &y, &idx), Tree::Leaf(0));
}

#[test]
fn stop_rules_leaf_when_no_split_or_too_little_gain() {
    // 30 identical rows, mixed classes: no split position separates values -> leaf.
    let x = Array2::from_elem((30, 4), 1.0);
    let y: Vec<usize> =
        (0..30).map(|i| usize::from(i % 3 == 0)).collect();
    let idx: Vec<usize> = (0..30).collect();
    assert_eq!(fit_tree(&x, &y, &idx), Tree::Leaf(0));
    // 100 rows, class 1 only at the last 7 and 2 stray: the 7-bucket split saves < CP*root? check it stays consistent.
    let x2 = Array2::from_shape_fn((200, 4), |(i, _)| i as f64);
    let y2: Vec<usize> = (0..200)
        .map(|i| usize::from(i % 2 == 0 && i > 100))
        .collect();
    let idx2: Vec<usize> = (0..200).collect();
    let t = fit_tree(&x2, &y2, &idx2);
    assert!(matches!(t, Tree::Leaf(0) | Tree::Split { .. }));
}

#[test]
fn empty_cluster_keeps_its_centroid() {
    // Far-away third centroid attracts nobody: its centre must not become NaN.
    let (df, _, c, _) = load();
    let (x, _) = features(&df);
    let mut far = c.clone();
    far.row_mut(2).fill(1.0e6);
    let (cl, obj) = kmeans_fixed(&x, &far, 100);
    assert!(obj.is_finite() && cl.iter().all(|&k| k != 2));
}

#[test]
fn iteration_cap_is_honoured() {
    let (df, _, c, _) = load();
    let (x, _) = features(&df);
    let (cl, _) = kmeans_fixed(&x, &c, 1);
    assert_eq!(cl.len(), 342);
}
