//! A-M1-P1: ingest Palmer Penguins, apply the NA policy, print the per-species counts.
//!
//! Provable contract: ads-rust-p1-v1 (344 rows loaded, 342 kept, counts 151/68/123).
use ads_rust::p1::{na_policy, read_penguins};

fn main() {
    let root = std::env::var("ADS_ROOT")
        .unwrap_or_else(|_| "../..".into());
    let raw = read_penguins(&format!(
        "{root}/datasets/penguins/penguins.csv"
    ))
    .expect("load");
    let kept = na_policy(raw.clone()).expect("policy");
    println!("rows loaded: {}", raw.height());
    println!("rows kept:   {}", kept.height());
    assert_eq!((raw.height(), kept.height()), (344, 342));
    {
        use ads_rust::figure::{
            group_points, penguin_rows, scatter_groups,
            write_if_out,
        };
        let rows =
            penguin_rows(&kept, "bill_length_mm", "bill_depth_mm");
        write_if_out(&scatter_groups(
            (
                "Penguin bills by species",
                "bill length (mm)",
                "bill depth (mm)",
            ),
            &group_points(rows.into_iter()),
        ));
    }
    let s =
        ads_rust::p1::summary_by_species(kept).expect("summary");
    let rows: Vec<ads_rust::plot::Row> =
        ["Adelie", "Chinstrap", "Gentoo"]
            .iter()
            .map(|sp| {
                (
                    format!("{sp:<9}"),
                    s["species"][*sp]["n"].as_f64().expect("n")
                        as usize,
                )
            })
            .collect();
    ads_rust::plot::plot(40, &rows);
    println!("contract: ads-rust-p1-v1 rows 344 -> 342 OK");
}
