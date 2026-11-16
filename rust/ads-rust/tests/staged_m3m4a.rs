use ads_rust::staged::root;
use ads_rust::staged_m3m4a::{kmeans_result, pipeline_result};
use std::process::Command;

fn run(example: &str) -> (bool, String) {
    let o = Command::new(env!("CARGO"))
        .args([
            "run",
            "-q",
            "--locked",
            "--offline",
            "--example",
            example,
        ])
        .current_dir(env!("CARGO_MANIFEST_DIR"))
        .output()
        .unwrap();
    (o.status.success(), String::from_utf8(o.stdout).unwrap())
}

fn heads(s: &str) -> Vec<&str> {
    s.lines().filter(|l| l.starts_with("== ")).collect()
}

fn fits(s: &str) {
    assert!(s.lines().count() <= 24, "{s}");
    assert!(
        s.lines().all(|l| l.len() <= 93 && l.is_ascii()),
        "{s}"
    );
}

#[test]
fn s_m3_02_stages_kmeans_source_then_result() {
    let (ok, out) = run("fixed-centroids");
    assert!(ok);
    assert_eq!(
        heads(&out),
        [
            "== source: examples/a-m3-p3-kmeans/main.rs 23,53-61 ==",
            "== run =="
        ]
    );
    assert!(out.trim_end().ends_with("e-12 OK"));
    let mut b = Vec::new();
    kmeans_result(&mut b, &root()).unwrap();
    let r = String::from_utf8(b).unwrap();
    assert!(r.starts_with("objective:     "));
    assert!(r.contains("\ncluster sizes: ["));
    assert!(out.ends_with(&r));
    fits(&out);
}

#[test]
fn s_m4_01_stages_pipeline_source_then_result() {
    let (ok, out) = run("whole-pipeline");
    assert!(ok);
    assert_eq!(
        heads(&out),
        [
            "== source: examples/a-m4-p4-pipeline/main.rs 12-13,35-43 ==",
            "== run =="
        ]
    );
    assert!(out.trim_end().ends_with("OK"));
    let mut b = Vec::new();
    pipeline_result(&mut b, &root()).unwrap();
    let r = String::from_utf8(b).unwrap();
    assert!(r.starts_with("rmse = "));
    assert!(r.contains("contract: ads-rust-p4-v1 pipeline"));
    assert!(out.ends_with(&r));
    fits(&out);
}

#[test]
fn s_m4_02_runs_the_child_tests() {
    let (ok, out) = run("data-validation");
    assert!(ok);
    assert_eq!(
        heads(&out),
        ["== source: src/p4.rs 53-65 ==", "== run =="]
    );
    assert!(out.contains(
        "$ cargo test -q --locked --offline --test p4\n"
    ));
    assert!(out.contains("test result: ok."));
    // the child's own result line may be wider than the screen and wrap: count rows with wrapping
    let rows: usize =
        out.lines().map(|l| l.len().div_ceil(93).max(1)).sum();
    assert!(rows <= 24 && out.is_ascii(), "{out}");
}
