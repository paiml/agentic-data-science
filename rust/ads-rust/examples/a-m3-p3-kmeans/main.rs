//! A-M3-P3b: k-means (k=3) from the committed initial centroids.
//!
//! Provable contract: ads-rust-p3-v1 (objective within 1e-6 of the golden file, cluster sizes exact).
use ads_rust::p1::{na_policy, read_penguins};
use ads_rust::p2::verdict;
use ads_rust::p3::{p3_json, read_centroids, read_split};

fn main() {
    let root = std::env::var("ADS_ROOT")
        .unwrap_or_else(|_| "../..".into());
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
    {
        use ads_rust::figure::{
            group_points, scatter_groups, write_if_out,
        };
        let (x, _) = ads_rust::p3::features(&df);
        let (cl, _) = ads_rust::p3::kmeans_fixed(&x, &cen, 100);
        let rows = cl.iter().enumerate().map(|(i, k)| {
            (format!("cluster {k}"), x[[i, 0]], x[[i, 2]])
        });
        write_if_out(&scatter_groups(
            (
                "k-means (k=3) clusters",
                "bill length (mm)",
                "flipper length (mm)",
            ),
            &group_points(rows),
        ));
    }
    println!(
        "objective:     {}\ncluster sizes: {}",
        got["kmeans"]["objective"], got["kmeans"]["cluster_sizes"]
    );
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
    let line = format!(
        "contract: ads-rust-p3-v1 kmeans max |diff| = {d:e} OK"
    );
    println!(
        "{}",
        verdict(
            &line,
            std::io::IsTerminal::is_terminal(&std::io::stdout())
        )
    );
}
