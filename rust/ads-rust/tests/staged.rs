use ads_rust::staged::{
    child, code, cv_result, ols_result, p1_contract, p3_result,
    pause, root, show, show_ranges, stage,
};
use std::io::{Error, ErrorKind};
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
fn s_m2_01_stages_source_then_result() {
    let mut b = Vec::new();
    show(
        &mut b,
        "x.rs",
        include_str!("../examples/a-m2-p2-ols/main.rs"),
        41,
        54,
    )
    .unwrap();
    stage(&mut b, "run").unwrap();
    ols_result(&mut b, &root()).unwrap();
    let s = String::from_utf8(b).unwrap();
    assert_eq!(
        heads(&s),
        ["== source: x.rs 41-54 ==", "== run =="]
    );
    assert!(s.lines().last().unwrap().contains("e-11 OK"));
    fits(&s);
    let (ok, out) = run("least-squares");
    assert!(ok);
    assert_eq!(
        heads(&out),
        [
            "== source: examples/a-m2-p2-ols/main.rs 41-54 ==",
            "== run =="
        ]
    );
    assert!(out.trim_end().ends_with("e-11 OK"));
    fits(&out);
}

#[test]
fn s_m1_03_runs_the_child_tests_then_the_contract() {
    let (ok, out) = run("unit-tests");
    assert!(ok);
    assert_eq!(
        heads(&out),
        [
            "== source: tests/p1.rs 31-46 ==",
            "== run ==",
            "== contract =="
        ]
    );
    assert!(out.contains(
        "$ cargo test -q --locked --offline --test p1\n"
    ));
    assert!(out.contains("test result: ok."));
    assert!(
        out.trim_end().ends_with(
            "contract: ads-rust-p1-v1 rows 344 -> 342 OK"
        )
    );
    let mut b = Vec::new();
    p1_contract(&mut b, &root()).unwrap();
    fits(&String::from_utf8(b).unwrap());
}

#[test]
fn s_m2_09_runs_the_child_tests() {
    let (ok, out) = run("problem-two-result");
    assert!(ok);
    assert_eq!(
        heads(&out),
        ["== source: src/p2.rs 148-151 ==", "== run =="]
    );
    assert!(out.contains(
        "$ cargo test -q --locked --offline --test p2\n"
    ));
    assert!(out.contains("test result: ok. 6 passed"));
}

#[test]
fn a_range_outside_the_file_is_refused() {
    for (f, t) in [(0, 2), (3, 2), (1, 99)] {
        let mut b = Vec::new();
        let e = show(&mut b, "x", "a\nb\nc\n", f, t).unwrap_err();
        assert_eq!(e.kind(), ErrorKind::InvalidInput);
        assert!(b.is_empty());
    }
}

#[test]
fn child_reports_success_failure_and_spawn_error() {
    let mut b = Vec::new();
    assert!(child(&mut b, "cargo", &["--version"]).unwrap());
    assert!(!child(&mut b, "cargo", &["--no-such-flag"]).unwrap());
    assert!(child(&mut b, "no-such-program-xyz", &[]).is_err());
    assert!(
        String::from_utf8(b)
            .unwrap()
            .starts_with("$ cargo --version\n")
    );
}

#[test]
fn pause_blocks_until_a_newline_or_eof() {
    let mut b = Vec::new();
    pause(&mut b, &mut "x\ny".as_bytes()).unwrap();
    pause(&mut b, &mut "".as_bytes()).unwrap();
    let mut r = "run\nrest".as_bytes();
    pause(&mut b, &mut r).unwrap();
    assert_eq!(r, b"rest");
}

#[test]
fn the_run_stage_waits_for_the_newline() {
    use std::io::{BufRead, BufReader, Write};
    use std::process::Stdio;
    use std::sync::mpsc;
    use std::time::Duration;
    let mut c = Command::new(env!("CARGO"))
        .args([
            "run",
            "-q",
            "--locked",
            "--offline",
            "--example",
            "least-squares",
        ])
        .current_dir(env!("CARGO_MANIFEST_DIR"))
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .unwrap();
    let (tx, rx) = mpsc::channel();
    let out = c.stdout.take().unwrap();
    std::thread::spawn(move || {
        for l in BufReader::new(out).lines() {
            tx.send(l.unwrap()).unwrap();
        }
    });
    let mut seen = Vec::new();
    while seen.len() < 15 {
        seen.push(
            rx.recv_timeout(Duration::from_secs(120)).unwrap(),
        );
    }
    assert!(rx.recv_timeout(Duration::from_millis(300)).is_err());
    assert!(!seen.iter().any(|l| l == "== run =="));
    writeln!(c.stdin.as_mut().unwrap()).unwrap();
    let rest: Vec<String> = rx.iter().collect();
    assert_eq!(rest[0], "== run ==");
    assert!(rest.last().unwrap().ends_with("e-11 OK"));
    assert!(c.wait().unwrap().success());
}

#[test]
fn exit_codes() {
    assert_eq!(code(Ok(true)), 0);
    assert_eq!(code(Ok(false)), 1);
    assert_eq!(code(Err(Error::other("x"))), 2);
}

#[test]
fn s_m2_02_stages_cv_source_then_result() {
    let (ok, out) = run("fixed-folds");
    assert!(ok);
    assert_eq!(
        heads(&out),
        [
            "== source: examples/a-m2-p2-cv/main.rs 48-64 ==",
            "== run =="
        ]
    );
    assert!(out.trim_end().ends_with("e-13 OK"));
    let mut b = Vec::new();
    cv_result(&mut b, &root()).unwrap();
    let r = String::from_utf8(b).unwrap();
    assert!(r.starts_with("cv_rmse (ols):     394.31"));
    assert!(out.ends_with(&r));
    fits(&out);
}

#[test]
fn s_m2_03_runs_the_child_tests() {
    let (ok, out) = run("problem-two-tests");
    assert!(ok);
    assert_eq!(
        heads(&out),
        ["== source: tests/p2.rs 43-58 ==", "== run =="]
    );
    assert!(out.contains(
        "$ cargo test -q --locked --offline --test p2\n"
    ));
    assert!(out.contains("test result: ok."));
    fits(&out);
}

#[test]
fn s_m3_01_stages_tree_source_then_result() {
    let (ok, out) = run("decision-tree");
    assert!(ok);
    assert_eq!(
        heads(&out),
        [
            "== source: examples/a-m3-p3-tree/main.rs 23,44-51 ==",
            "== run =="
        ]
    );
    assert!(out.trim_end().ends_with("confusion equals golden OK"));
    let mut b = Vec::new();
    p3_result(&mut b, &root()).unwrap();
    let r = String::from_utf8(b).unwrap();
    assert!(r.starts_with("accuracy:  "));
    assert!(out.ends_with(&r));
    fits(&out);
}

#[test]
fn show_ranges_prints_each_range_under_one_header() {
    let mut b = Vec::new();
    show_ranges(&mut b, "x", "a\nb\nc\nd\n", &[(1, 1), (3, 4)])
        .unwrap();
    assert_eq!(
        String::from_utf8(b).unwrap(),
        "== source: x 1,3-4 ==\na\nc\nd\n"
    );
}

#[test]
fn a_bad_range_among_several_prints_nothing() {
    for r in [[(1, 2), (0, 1)], [(1, 2), (3, 2)], [(1, 2), (1, 9)]]
    {
        let mut b = Vec::new();
        let e =
            show_ranges(&mut b, "x", "a\nb\nc\n", &r).unwrap_err();
        assert_eq!(e.kind(), ErrorKind::InvalidInput);
        assert!(b.is_empty());
    }
}
