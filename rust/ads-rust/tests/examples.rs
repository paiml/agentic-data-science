use std::process::Command;

/// Runs a built example and returns (success, last stdout line).
fn run_example(name: &str) -> (bool, String) {
    let out = Command::new(env!("CARGO"))
        .args(["run", "-q", "--locked", "--example", name])
        .env("ADS_ROOT", "../..")
        .output()
        .unwrap();
    let stdout = String::from_utf8(out.stdout).unwrap();
    let last = stdout.lines().last().unwrap_or("").to_string();
    (out.status.success(), last)
}

fn assert_verdict(name: &str) {
    let (ok, last) = run_example(name);
    assert!(ok, "{name} exited non-zero");
    assert!(
        last.starts_with("contract: ") && last.ends_with(" OK"),
        "{name} last line is not an OK verdict: {last}"
    );
}

#[test]
fn a_m1_p1_last_line_is_the_ok_verdict() {
    assert_verdict("a-m1-p1");
}

#[test]
fn a_m1_p1_profile_last_line_is_the_ok_verdict() {
    assert_verdict("a-m1-p1-profile");
}
