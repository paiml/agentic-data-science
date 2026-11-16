use ads_rust::staged::{
    cv_result, p1_counts, p1_profile, pause, root, show, stage,
};
use std::process::{Command, Stdio};

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
        .stdin(Stdio::null())
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
fn s_m1_01_stages_source_then_counts() {
    let (ok, out) = run("first-data-load");
    assert!(ok);
    assert_eq!(
        heads(&out),
        [
            "== source: examples/a-m1-p1/main.rs 9-16 ==",
            "== run =="
        ]
    );
    let mut b = Vec::new();
    p1_counts(&mut b, &root()).unwrap();
    let r = String::from_utf8(b).unwrap();
    assert!(r.starts_with("rows loaded: 344\nrows kept:   342\n"));
    assert!(r.trim_end().ends_with("rows 344 -> 342 OK"));
    assert!(out.ends_with(&r));
    fits(&out);
}

#[test]
fn s_m1_02_stages_source_then_gap() {
    let (ok, out) = run("species-profile");
    assert!(ok);
    assert_eq!(
        heads(&out),
        [
            "== source: examples/a-m1-p1-profile/main.rs 46-48 ==",
            "== run =="
        ]
    );
    let mut b = Vec::new();
    p1_profile(&mut b, &root()).unwrap();
    let r = String::from_utf8(b).unwrap();
    assert!(
        r.starts_with("contract: ads-rust-p1-v1 max |diff| = ")
    );
    assert!(r.trim_end().ends_with("OK"));
    assert!(out.ends_with(&r));
    fits(&out);
}

#[test]
fn s_m2_08_stages_fit_source_then_cv() {
    let (ok, out) = run("model-fit-linfa");
    assert!(ok);
    assert_eq!(
        heads(&out),
        ["== source: src/p2.rs 67-85 ==", "== run =="]
    );
    let mut b = Vec::new();
    cv_result(&mut b, &root()).unwrap();
    let r = String::from_utf8(b).unwrap();
    assert!(out.ends_with(&r));
    assert!(out.trim_end().ends_with("e-13 OK"));
    fits(&out);
}

#[test]
fn each_stage_pauses_between_source_and_result() {
    let mut b = Vec::new();
    show(&mut b, "x", "a\nb\n", 1, 2).unwrap();
    pause(&mut b, &mut "run\n".as_bytes()).unwrap();
    stage(&mut b, "run").unwrap();
    assert!(String::from_utf8(b).unwrap().ends_with("== run ==\n"));
}
