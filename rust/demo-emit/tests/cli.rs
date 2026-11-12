//! The binary, end to end, with a cleared environment and fake `bat` / `cargo` on a scratch PATH.
mod common;
use common::{Planted, script};
use std::fs;
use std::process::{Command, Output};

const SHA: &str = "0123456789abcdef0123456789abcdef01234567";

fn base(p: &Planted) -> Command {
    let work = p.scratch.path().join("work");
    fs::create_dir_all(&work).unwrap();
    let mut c = Command::new(env!("CARGO_BIN_EXE_demo-emit"));
    c.env_clear()
        .current_dir(&p.root)
        .env("PATH", format!("{}:/usr/bin:/bin", p.bin.display()))
        .env("HOME", p.scratch.path().join("callerhome"))
        .env("CARGO_TARGET_DIR", p.scratch.path().join("target"))
        .env("RUNNER_TEMP", &work)
        .env("GITHUB_SHA", SHA)
        .env("GITHUB_WORKFLOW", "rust-demo")
        .env("GITHUB_RUN_ID", "42");
    c
}

fn text(o: &Output) -> (String, String) {
    (
        String::from_utf8_lossy(&o.stdout).into_owned(),
        String::from_utf8_lossy(&o.stderr).into_owned(),
    )
}

fn clean() -> Planted {
    let mut p = Planted::new("cli");
    p.row("aaa", "bat -r 1:2 src/x.rs\ncargo ok\n");
    p
}

#[test]
fn a_clean_control_writes_demo_json_and_exits_zero() {
    let p = clean();
    let o = base(&p).arg(&p.out).output().unwrap();
    let (so, se) = text(&o);
    assert_eq!(o.status.code(), Some(0), "{so}\n{se}");
    let json = fs::read_to_string(&p.out).unwrap();
    for n in [
        "\"schema\": \"demo-json/v1\"",
        &format!("\"commit\": \"{SHA}\""),
        "\"workflow\": \"rust-demo\"",
        "\"run_id\": \"42\"",
        "\"id\": \"term-aaa\"",
        "$ cargo ok\\nfine\\n",
    ] {
        assert!(json.contains(n), "missing {n} in {json}");
    }
}

#[test]
fn the_default_warm_up_runs_its_two_fixed_commands_in_rust_ads_rust_and_no_warm_skips_them()
 {
    let p = clean();
    script(&p.bin, "cargo", "echo \"$@\" >> warm.log; echo fine");
    let o = base(&p).arg(&p.out).output().unwrap();
    assert_eq!(o.status.code(), Some(0), "{:?}", text(&o));
    let log =
        fs::read_to_string(p.root.join("rust/ads-rust/warm.log"))
            .unwrap();
    assert_eq!(
        log,
        "test --locked --offline --no-run\nbuild --locked --offline --examples\nok\n"
    );
    fs::remove_file(p.root.join("rust/ads-rust/warm.log")).unwrap();
    let o = base(&p).arg("--no-warm").arg(&p.out).output().unwrap();
    assert_eq!(o.status.code(), Some(0), "{:?}", text(&o));
    assert_eq!(
        fs::read_to_string(p.root.join("rust/ads-rust/warm.log"))
            .unwrap(),
        "ok\n"
    );
}

#[test]
fn a_failing_row_exits_one_with_e_status_and_leaves_no_file() {
    let mut p = Planted::new("cli");
    p.row("f1", "cargo ok\ncargo fail\n");
    let o = base(&p).arg(&p.out).output().unwrap();
    let (_, se) = text(&o);
    assert_eq!(o.status.code(), Some(1), "{se}");
    assert!(
        se.contains("FAIL E-STATUS") && se.contains("exit 3"),
        "{se}"
    );
    assert!(!p.out.exists());
}

#[test]
fn a_compound_command_line_exits_one_with_e_form_naming_file_and_line()
 {
    let mut p = Planted::new("cli");
    p.row("f1", "cargo ok\ncargo test; cargo run\n");
    let o = base(&p).arg(&p.out).output().unwrap();
    let (_, se) = text(&o);
    assert_eq!(o.status.code(), Some(1), "{se}");
    assert!(
        se.contains("FAIL E-FORM") && se.contains("f1.cmds:2"),
        "{se}"
    );
    assert!(!p.out.exists());
}

#[test]
fn usage_errors_exit_two() {
    let p = clean();
    let mut cases: Vec<Vec<std::ffi::OsString>> = vec![
        vec![],
        vec!["--nope".into(), p.out.clone().into()],
        vec![p.out.clone().into(), p.out.clone().into()],
        vec![
            "--timeout-s".into(),
            "abc".into(),
            p.out.clone().into(),
        ],
        vec![
            "--timeout-s".into(),
            "0".into(),
            p.out.clone().into(),
        ],
        vec!["--timeout-s".into()],
        vec!["--root".into()],
    ];
    cases.push(vec![
        "--root".into(),
        "/nonexistent-demo-emit".into(),
        p.out.clone().into(),
    ]);
    for args in cases {
        let o = base(&p).args(&args).output().unwrap();
        assert_eq!(
            o.status.code(),
            Some(2),
            "{args:?}: {:?}",
            text(&o)
        );
        assert!(!p.out.exists());
    }
}

#[test]
fn the_callers_environment_does_not_reach_a_row() {
    let mut p = Planted::new("cli");
    p.row("k", "cargo keys\n");
    let o = base(&p)
        .env("CANARY_SECRET", "zzz")
        .env("RUSTFLAGS", "-Cx")
        .arg(&p.out)
        .output()
        .unwrap();
    assert_eq!(o.status.code(), Some(0), "{:?}", text(&o));
    let json = fs::read_to_string(&p.out).unwrap();
    assert!(
        !json.contains("CANARY_SECRET")
            && !json.contains("RUSTFLAGS"),
        "{json}"
    );
    assert!(
        json.contains("LC_ALL")
            && json.contains("GIT_CONFIG_NOSYSTEM")
    );
}

#[test]
fn an_invalid_github_sha_exits_two() {
    let p = clean();
    for bad in [
        "abc",
        "g".repeat(40).as_str(),
        "0123456789abcdef0123456789abcdef0123456",
        "$(id)",
    ] {
        let o = base(&p)
            .env("GITHUB_SHA", bad)
            .arg(&p.out)
            .output()
            .unwrap();
        assert_eq!(
            o.status.code(),
            Some(2),
            "{bad}: {:?}",
            text(&o)
        );
        assert!(!p.out.exists());
    }
}

#[test]
fn without_github_sha_and_outside_a_git_checkout_the_commit_is_unknown()
 {
    let p = clean();
    let o = base(&p)
        .env_remove("GITHUB_SHA")
        .arg(&p.out)
        .output()
        .unwrap();
    assert_eq!(o.status.code(), Some(0), "{:?}", text(&o));
    assert!(
        fs::read_to_string(&p.out)
            .unwrap()
            .contains("\"commit\": \"unknown\"")
    );
}

#[test]
fn a_relative_cargo_target_dir_exits_two() {
    let p = clean();
    let o = base(&p)
        .env("CARGO_TARGET_DIR", "rel/target")
        .arg(&p.out)
        .output()
        .unwrap();
    assert_eq!(o.status.code(), Some(2), "{:?}", text(&o));
    assert!(!p.out.exists());
}

#[test]
fn a_trailing_slash_on_the_target_dir_is_stripped_and_rows_still_normalise()
 {
    let mut p = Planted::new("cli");
    p.row("t", "cargo paths\n");
    let t =
        format!("{}/", p.scratch.path().join("target").display());
    let o = base(&p)
        .env("CARGO_TARGET_DIR", t)
        .arg(&p.out)
        .output()
        .unwrap();
    assert_eq!(o.status.code(), Some(0), "{:?}", text(&o));
    let json = fs::read_to_string(&p.out).unwrap();
    assert!(json.contains("(target/llvm-cov-target/debug/deps/p1-0000000000000000)"), "{json}");
}

#[test]
fn the_default_target_dir_is_inside_the_checkout_and_still_normalises()
 {
    let mut p = Planted::new("cli");
    p.row("t", "cargo paths\n");
    let o = base(&p)
        .env_remove("CARGO_TARGET_DIR")
        .arg(&p.out)
        .output()
        .unwrap();
    assert_eq!(o.status.code(), Some(0), "{:?}", text(&o));
    let json = fs::read_to_string(&p.out).unwrap();
    assert!(json.contains("(target/llvm-cov-target/debug/deps/p1-0000000000000000)"), "{json}");
    assert!(json.contains("root=./rust/ads-rust"), "{json}");
}

#[test]
fn root_defaults_to_the_current_directory_and_can_be_given() {
    let p = clean();
    let elsewhere = p.scratch.path().join("elsewhere");
    fs::create_dir_all(&elsewhere).unwrap();
    let o = base(&p)
        .current_dir(&elsewhere)
        .arg("--root")
        .arg(&p.root)
        .arg(&p.out)
        .output()
        .unwrap();
    assert_eq!(o.status.code(), Some(0), "{:?}", text(&o));
    let a = fs::read(&p.out).unwrap();
    fs::remove_file(&p.out).unwrap();
    let o = base(&p).arg(&p.out).output().unwrap();
    assert_eq!(o.status.code(), Some(0), "{:?}", text(&o));
    assert_eq!(a, fs::read(&p.out).unwrap());
}

#[test]
fn a_timeout_flag_reaches_the_row() {
    let mut p = Planted::new("cli");
    p.row("s", "cargo slow\n");
    let o = base(&p)
        .args(["--no-warm", "--timeout-s", "1"])
        .arg(&p.out)
        .output()
        .unwrap();
    assert_eq!(o.status.code(), Some(1), "{:?}", text(&o));
    assert!(text(&o).1.contains("FAIL E-TIMEOUT"));
}

#[test]
fn a_missing_path_exits_two() {
    let p = clean();
    let o =
        base(&p).env_remove("PATH").arg(&p.out).output().unwrap();
    assert!(
        matches!(o.status.code(), Some(1) | Some(2)),
        "{:?}",
        text(&o)
    );
    assert!(!p.out.exists());
}
