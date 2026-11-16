use std::process::Command;
use std::sync::Mutex;

// Both lessons run the real p4 tests, which use fixed temp paths:
// two p4 runs at once collide, so the two checks take turns.
static P4: Mutex<()> = Mutex::new(());

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

fn check(example: &str, head: &str, first: &str) {
    let _turn = P4.lock().unwrap_or_else(|e| e.into_inner());
    let (ok, out) = run(example);
    assert!(ok);
    assert_eq!(heads(&out), [head, "== run =="]);
    assert!(out.lines().nth(1).unwrap().contains(first));
    assert!(out.contains(
        "$ cargo test -q --locked --offline --test p4\n"
    ));
    assert!(out.contains("test result: ok."));
    assert!(out.is_ascii());
}

#[test]
fn s_m4_08_shows_bench_wine_then_runs_the_p4_tests() {
    check(
        "benchmark-helper",
        "== source: src/p4.rs 212-235 ==",
        "pub fn bench_wine(",
    );
}

#[test]
fn s_m4_09_shows_report_ttl_then_runs_the_p4_tests() {
    check(
        "report-artifact",
        "== source: src/p4.rs 238-251 ==",
        "pub fn report_ttl(",
    );
}
