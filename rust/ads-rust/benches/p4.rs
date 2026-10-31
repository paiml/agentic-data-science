//! Criterion benchmark of the two grouped-mean engines (timings are never part of parity).
use ads_rust::p4::{aggregate_map, aggregate_polars, read_wine};
use criterion::{criterion_group, criterion_main, Criterion};

fn grouped_mean(c: &mut Criterion) {
    let root = std::env::var("ADS_ROOT")
        .unwrap_or_else(|_| "../..".into());
    let wine = |k: &str| {
        format!("{root}/datasets/wine-quality/winequality-{k}.csv")
    };
    let df = read_wine(&wine("red"), &wine("white")).expect("load");
    c.bench_function("polars", |b| {
        b.iter(|| aggregate_polars(&df))
    });
    c.bench_function("btreemap", |b| b.iter(|| aggregate_map(&df)));
}

criterion_group!(benches, grouped_mean);
criterion_main!(benches);
