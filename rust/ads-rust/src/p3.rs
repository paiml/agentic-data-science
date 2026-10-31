//! P3: species classifier (CART, rpart defaults) and k-means from fixed initial centroids.
use ndarray::{Array1, Array2, Axis};
use polars::prelude::DataFrame;
use serde_json::{Value, json};

use crate::p1::MEASURES;

/// rpart defaults: a node needs `MINSPLIT` rows, each child `MINBUCKET`, and a split must remove
/// at least `CP` of the root's misclassification count.
pub const MINSPLIT: usize = 20;
pub const MINBUCKET: usize = 7;
pub const CP: f64 = 0.01;
pub const CLASSES: [&str; 3] = ["Adelie", "Chinstrap", "Gentoo"];

/// A fitted tree: a leaf predicts a class, a split sends `x[feature] < threshold` left.
#[derive(Debug, PartialEq)]
pub enum Tree {
    Leaf(usize),
    Split {
        feature: usize,
        threshold: f64,
        left: Box<Tree>,
        right: Box<Tree>,
    },
}

/// Feature matrix (rows x four measurements) and class index per row of a cleaned frame.
pub fn features(df: &DataFrame) -> (Array2<f64>, Vec<usize>) {
    let mut x = Array2::zeros((df.height(), MEASURES.len()));
    for (j, m) in MEASURES.iter().enumerate() {
        for (i, v) in df
            .column(m)
            .expect("col")
            .f64()
            .expect("f64")
            .into_no_null_iter()
            .enumerate()
        {
            x[[i, j]] = v;
        }
    }
    let y = df
        .column("species")
        .expect("species")
        .str()
        .expect("str")
        .into_no_null_iter()
        .map(|s| {
            CLASSES
                .iter()
                .position(|c| *c == s)
                .expect("known species")
        })
        .collect();
    (x, y)
}

/// Train/test flag per cleaned row from the committed split file (true = train).
pub fn read_split(path: &str) -> Vec<bool> {
    std::fs::read_to_string(path)
        .expect("split file")
        .lines()
        .skip(1)
        .map(|l| {
            l.split(',').nth(1).expect("set").trim() == "train"
        })
        .collect()
}

/// Initial centroids (raw units), one row per cluster.
pub fn read_centroids(path: &str) -> Array2<f64> {
    let rows: Vec<Vec<f64>> = std::fs::read_to_string(path)
        .expect("centroids file")
        .lines()
        .skip(1)
        .map(|l| {
            l.split(',')
                .skip(1)
                .map(|v| v.trim().parse().expect("number"))
                .collect()
        })
        .collect();
    Array2::from_shape_fn((rows.len(), MEASURES.len()), |(i, j)| {
        rows[i][j]
    })
}

fn counts(y: &[usize], idx: &[usize]) -> [usize; 3] {
    let mut c = [0; 3];
    for &i in idx {
        c[y[i]] += 1;
    }
    c
}

fn majority(c: &[usize; 3]) -> usize {
    (0..3).fold(0, |b, k| if c[k] > c[b] { k } else { b })
}

/// Misclassification count of predicting the majority class.
fn risk(c: &[usize; 3]) -> usize {
    c.iter().sum::<usize>() - c[majority(c)]
}

fn gini_n(c: &[usize; 3]) -> f64 {
    // Callers pass non-empty nodes: MINBUCKET keeps every child at 7 rows or more.
    let n = c.iter().sum::<usize>() as f64;
    n * (1.0
        - c.iter().map(|&k| (k as f64 / n).powi(2)).sum::<f64>())
}

/// Best Gini split of `idx` honouring `MINBUCKET`: (improvement, feature, threshold).
fn best_split(
    x: &Array2<f64>,
    y: &[usize],
    idx: &[usize],
) -> Option<(f64, usize, f64)> {
    let parent = gini_n(&counts(y, idx));
    let mut best: Option<(f64, usize, f64)> = None;
    for f in 0..x.ncols() {
        let mut order = idx.to_vec();
        order.sort_by(|&a, &b| x[[a, f]].total_cmp(&x[[b, f]]));
        let mut left = [0usize; 3];
        let total = counts(y, idx);
        for p in 0..order.len() - 1 {
            left[y[order[p]]] += 1;
            let (a, b) = (x[[order[p], f]], x[[order[p + 1], f]]);
            let nl = p + 1;
            if a == b
                || nl < MINBUCKET
                || order.len() - nl < MINBUCKET
            {
                continue;
            }
            let right = [
                total[0] - left[0],
                total[1] - left[1],
                total[2] - left[2],
            ];
            let gain = parent - gini_n(&left) - gini_n(&right);
            if best.is_none_or(|(g, _, _)| gain > g) {
                best = Some((gain, f, (a + b) / 2.0));
            }
        }
    }
    best
}

fn grow(
    x: &Array2<f64>,
    y: &[usize],
    idx: &[usize],
    root_risk: usize,
) -> Tree {
    let c = counts(y, idx);
    let leaf = Tree::Leaf(majority(&c));
    if idx.len() < MINSPLIT || risk(&c) == 0 {
        return leaf;
    }
    let Some((_, feature, threshold)) = best_split(x, y, idx)
    else {
        return leaf;
    };
    let (l, r): (Vec<usize>, Vec<usize>) =
        idx.iter().partition(|&&i| x[[i, feature]] < threshold);
    let saved = risk(&c) as f64
        - (risk(&counts(y, &l)) + risk(&counts(y, &r))) as f64;
    if saved < CP * root_risk as f64 {
        return leaf;
    }
    Tree::Split {
        feature,
        threshold,
        left: Box::new(grow(x, y, &l, root_risk)),
        right: Box::new(grow(x, y, &r, root_risk)),
    }
}

/// Fit a CART tree on the rows `idx` (Gini splits, rpart-style stopping rules).
pub fn fit_tree(
    x: &Array2<f64>,
    y: &[usize],
    idx: &[usize],
) -> Tree {
    grow(x, y, idx, risk(&counts(y, idx)))
}

/// Class predicted for one feature row.
pub fn predict_one(t: &Tree, row: &[f64]) -> usize {
    match t {
        Tree::Leaf(k) => *k,
        Tree::Split {
            feature,
            threshold,
            left,
            right,
        } => predict_one(
            if row[*feature] < *threshold {
                left
            } else {
                right
            },
            row,
        ),
    }
}

/// Confusion matrix, truth in rows and prediction in columns.
pub fn confusion(truth: &[usize], pred: &[usize]) -> [[u32; 3]; 3] {
    let mut m = [[0; 3]; 3];
    for (&t, &p) in truth.iter().zip(pred) {
        m[t][p] += 1;
    }
    m
}

/// Share of correct predictions.
pub fn accuracy(truth: &[usize], pred: &[usize]) -> f64 {
    truth.iter().zip(pred).filter(|(t, p)| t == p).count() as f64
        / truth.len() as f64
}

/// Lloyd k-means on z-scored features (sample SD) from fixed raw-unit centroids.
/// Returns (cluster per row, objective in z units).
pub fn kmeans_fixed(
    x: &Array2<f64>,
    centroids: &Array2<f64>,
    max_iter: usize,
) -> (Vec<usize>, f64) {
    let centre = x.mean_axis(Axis(0)).expect("rows");
    let spread = x.std_axis(Axis(0), 1.0);
    let z = (x - &centre) / &spread;
    let mut cen = (centroids - &centre) / &spread;
    let mut cluster = vec![usize::MAX; z.nrows()];
    for _ in 0..max_iter {
        let next: Vec<usize> = z
            .rows()
            .into_iter()
            .map(|r| {
                let d: Vec<f64> = cen
                    .rows()
                    .into_iter()
                    .map(|c| (&r - &c).mapv(|v| v * v).sum())
                    .collect();
                (0..d.len())
                    .fold(0, |b, k| if d[k] < d[b] { k } else { b })
            })
            .collect();
        if next == cluster {
            break;
        }
        cluster = next;
        for k in 0..cen.nrows() {
            let rows: Vec<usize> = (0..z.nrows())
                .filter(|&i| cluster[i] == k)
                .collect();
            if !rows.is_empty() {
                cen.row_mut(k).assign(
                    &z.select(Axis(0), &rows)
                        .mean_axis(Axis(0))
                        .expect("rows"),
                );
            }
        }
    }
    let objective = (0..z.nrows())
        .map(|i| {
            (&z.row(i) - &cen.row(cluster[i])).mapv(|v| v * v).sum()
        })
        .sum();
    (cluster, objective)
}

/// The golden-file layout for P3.
pub fn p3_json(
    df: &DataFrame,
    train: &[bool],
    centroids: &Array2<f64>,
) -> Value {
    let (x, y) = features(df);
    let tr: Vec<usize> =
        (0..y.len()).filter(|&i| train[i]).collect();
    let te: Vec<usize> =
        (0..y.len()).filter(|&i| !train[i]).collect();
    let tree = fit_tree(&x, &y, &tr);
    let truth: Vec<usize> = te.iter().map(|&i| y[i]).collect();
    let pred: Vec<usize> = te
        .iter()
        .map(|&i| {
            predict_one(&tree, x.row(i).as_slice().expect("row"))
        })
        .collect();
    let (cluster, objective) = kmeans_fixed(&x, centroids, 100);
    let sizes: Array1<usize> = (0..centroids.nrows())
        .map(|k| cluster.iter().filter(|&&c| c == k).count())
        .collect();
    json!({
        "accuracy": accuracy(&truth, &pred),
        "confusion": confusion(&truth, &pred),
        "classes": CLASSES,
        "kmeans": {"objective": objective, "cluster_sizes": sizes.to_vec()},
    })
}
