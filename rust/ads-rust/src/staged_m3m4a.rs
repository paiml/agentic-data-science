//! Result stages of the staged demos for the k-means and pipeline lessons.
//! Plain ASCII, no colour codes; every number comes from the library calls.
use std::io::{self, Write};

use crate::p1::{na_policy, read_penguins};
use crate::p3::{p3_json, read_centroids, read_split};
use crate::p4::{pipeline_wine, report_ttl};

/// The k-means stage of `a-m3-p3-kmeans`: objective and cluster sizes, then the golden-file contract line.
pub fn kmeans_result(
    out: &mut impl Write,
    root: &str,
) -> io::Result<()> {
    let df = na_policy(
        read_penguins(&format!(
            "{root}/datasets/penguins/penguins.csv"
        ))
        .expect("load"),
    )
    .expect("policy");
    let split =
        read_split(&format!("{root}/datasets/fixtures/split.csv"));
    let cen = read_centroids(&format!(
        "{root}/datasets/fixtures/centroids.csv"
    ));
    let got = p3_json(&df, &split, &cen);
    let head = format!(
        "objective:     {}\ncluster sizes: {}",
        got["kmeans"]["objective"], got["kmeans"]["cluster_sizes"]
    );
    writeln!(out, "{head}")?;
    let g: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(format!(
            "{root}/datasets/golden/p3.json"
        ))
        .expect("golden"),
    )
    .expect("parse");
    let d = (got["kmeans"]["objective"].as_f64().expect("obj")
        - g["kmeans"]["objective"].as_f64().expect("gold"))
    .abs();
    assert!(
        d <= 1e-6
            && got["kmeans"]["cluster_sizes"]
                == g["kmeans"]["cluster_sizes"],
        "diff {d}"
    );
    writeln!(
        out,
        "contract: ads-rust-p3-v1 kmeans max |diff| = {d:e} OK"
    )
}

/// The pipeline stage of `a-m4-p4-pipeline`: scores, then the golden-file and artifact contract line.
pub fn pipeline_result(
    out: &mut impl Write,
    root: &str,
) -> io::Result<()> {
    let wine = |c: &str| {
        format!("{root}/datasets/wine-quality/winequality-{c}.csv")
    };
    let res = pipeline_wine(&wine("red"), &wine("white"))
        .expect("pipeline");
    let head =
        format!("rmse = {:.6}, r2 = {:.6}", res["rmse"], res["r2"]);
    writeln!(out, "{head}")?;
    let g: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(format!(
            "{root}/datasets/golden/p4.json"
        ))
        .expect("golden"),
    )
    .expect("parse");
    let d = (res["rmse"].as_f64().expect("rmse")
        - g["rmse"].as_f64().expect("g"))
    .abs();
    assert!(d <= 1e-6, "diff {d}");
    let ttl = std::fs::read_to_string(format!(
        "{root}/datasets/golden/p4-artifact.ttl"
    ))
    .expect("ttl");
    assert_eq!(report_ttl(&res).expect("ttl"), ttl);
    writeln!(
        out,
        "contract: ads-rust-p4-v1 pipeline |rmse diff| = {d:e} OK"
    )
}
