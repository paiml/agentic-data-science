//! The emitter against planted row sets with fake `bat` and `cargo` programs on a scratch PATH.
mod common;
use common::{Planted, Scratch};
use demo_emit::emit::{Config, Refusal, emit, validate};
use demo_emit::env::Host;
use demo_emit::sha256::sha256_hex;
use std::fs;
use std::time::Duration;

fn cfg(p: &Planted) -> Config {
    let work = p.scratch.path().join("work");
    fs::create_dir_all(&work).unwrap();
    Config {
        root: p.root.clone(),
        term_dir: p.term.clone(),
        out: p.out.clone(),
        target_dir: p.scratch.path().join("target"),
        allow: vec!["bat".into(), "cargo".into(), "make".into()],
        warm: vec![],
        warm_cwd: "rust/ads-rust".into(),
        timeout: Duration::from_secs(20),
        host: Host {
            path: Some(format!(
                "{}:/usr/bin:/bin",
                p.bin.display()
            )),
            home: Some(
                p.scratch
                    .path()
                    .join("callerhome")
                    .display()
                    .to_string(),
            ),
            cargo_home: None,
            rustup_home: None,
        },
        work_parent: work,
        commit: "0".repeat(40),
        workflow: "test".into(),
        run_id: "1".into(),
    }
}

fn codes(e: &[Refusal]) -> Vec<&'static str> {
    e.iter().map(|r| r.code).collect()
}

/// Run the emitter, expect a refusal with `code`, and expect that no demo.json (or temp file) exists.
fn refused(p: &Planted, code: &str) -> Vec<Refusal> {
    let c = cfg(p);
    let e = emit(&c).expect_err("the planted defect was accepted");
    assert!(codes(&e).contains(&code), "wanted {code}, got {e:?}");
    assert!(
        !p.out.exists(),
        "a demo.json was written on a refusal"
    );
    let left: Vec<_> =
        fs::read_dir(p.out.parent().unwrap()).unwrap().collect();
    assert!(left.is_empty(), "a temp file was left: {left:?}");
    e
}

fn clean() -> Planted {
    let mut p = Planted::new("emit");
    p.row("aaa111", "bat -r 1:2 src/x.rs\ncargo ok\n");
    p.row("bbb222", "cargo test\ncargo paths\n");
    p
}

#[test]
fn a_clean_control_emits_every_pinned_row_with_the_row_shape() {
    let p = clean();
    let r = emit(&cfg(&p)).unwrap();
    assert_eq!(r.rows.len(), 2);
    assert_eq!(r.rows[0].id, "term-aaa111");
    assert_eq!(r.rows[1].id, "term-bbb222");
    assert_eq!(
        r.rows[0].command,
        "bat -r 1:2 src/x.rs\ncargo ok\n"
    );
    assert_eq!(
        r.rows[0].commands,
        ["bat -r 1:2 src/x.rs", "cargo ok"]
    );
    assert_eq!(r.rows[0].exit, 0);
    assert_eq!(
        r.rows[0].stdout,
        "$ bat -r 1:2 src/x.rs\n   1   fake bat -r 1:2 src/x.rs\n$ cargo ok\nfine\n"
    );
    assert_eq!(
        r.rows[0].stdout_sha256,
        sha256_hex(r.rows[0].stdout.as_bytes())
    );
    let json = fs::read_to_string(&p.out).unwrap();
    for needle in [
        "\"schema\": \"demo-json/v1\"",
        "\"course\": \"ads-c01-rust\"",
        &format!("\"commit\": \"{}\"", "0".repeat(40)),
        "\"workflow\": \"test\"",
        "\"run_id\": \"1\"",
        "\"id\": \"term-aaa111\"",
        "\"commands\": [",
        "\"exit\": 0",
        "\"plots\": []",
        &format!(
            "\"stdout_sha256\": \"{}\"",
            r.rows[1].stdout_sha256
        ),
    ] {
        assert!(
            json.contains(needle),
            "missing {needle} in {json}"
        );
    }
    assert!(json.ends_with("}\n"));
}

#[test]
fn normalisation_reaches_the_row_output() {
    let p = clean();
    let r = emit(&cfg(&p)).unwrap();
    assert_eq!(
        r.rows[1].stdout,
        "$ cargo test\nrunning 1 test\ntest result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s\n\
         $ cargo paths\n     Running tests/p1.rs (target/llvm-cov-target/debug/deps/p1-0000000000000000)\nroot=./rust/ads-rust\ndone in 0.00s\n"
    );
}

#[test]
fn two_checkouts_at_different_paths_give_the_same_bytes() {
    let a = clean();
    let b = clean();
    let ra = emit(&cfg(&a)).unwrap();
    let rb = emit(&cfg(&b)).unwrap();
    for (x, y) in ra.rows.iter().zip(&rb.rows) {
        assert_eq!(x.stdout_sha256, y.stdout_sha256);
    }
    assert_eq!(
        fs::read(&a.out).unwrap(),
        fs::read(&b.out).unwrap()
    );
}

#[test]
fn rows_run_in_byte_order_of_their_ids() {
    let mut p = Planted::new("order");
    p.row("zzz", "cargo ok\n");
    p.row("aaa", "cargo ok\n");
    let r = emit(&cfg(&p)).unwrap();
    assert_eq!(r.rows[0].id, "term-aaa");
}

#[test]
fn the_session_environment_is_exactly_the_owned_keys_and_the_env_file()
 {
    let mut p = Planted::new("keys");
    p.row("k", "cargo keys\n");
    let r = emit(&cfg(&p)).unwrap();
    let keys: Vec<&str> =
        r.rows[0].stdout.lines().skip(1).collect();
    for want in [
        "BAT_STYLE",
        "CARGO_HOME",
        "CARGO_INCREMENTAL",
        "CARGO_TARGET_DIR",
        "HOME",
        "LC_ALL",
        "PATH",
        "PS1",
        "RUSTUP_HOME",
        "TERM",
        "TZ",
        "GIT_CONFIG_NOSYSTEM",
        "GIT_CONFIG_GLOBAL",
        "GIT_CONFIG_COUNT",
    ] {
        assert!(
            keys.contains(&want),
            "{want} missing from {keys:?}"
        );
    }
    for k in &keys {
        assert!(
            [
                "BAT_STYLE",
                "CARGO_HOME",
                "CARGO_INCREMENTAL",
                "CARGO_TARGET_DIR",
                "HOME",
                "LC_ALL",
                "PATH",
                "PS1",
                "RUSTUP_HOME",
                "TERM",
                "TZ",
                "GIT_CONFIG_NOSYSTEM",
                "GIT_CONFIG_GLOBAL",
                "GIT_CONFIG_COUNT",
                "GIT_CONFIG_KEY_0",
                "GIT_CONFIG_VALUE_0",
                "PWD",
                "OLDPWD",
                "SHLVL",
                "_",
            ]
            .contains(k),
            "unexpected variable {k}"
        );
    }
}

#[test]
fn the_warm_up_runs_first_in_its_cwd_and_is_not_recorded() {
    let mut p = Planted::new("warm");
    p.row("w", "cargo ok\n");
    let mut c = cfg(&p);
    c.warm = vec![vec!["cargo".into(), "marker".into()]];
    let r = emit(&c).unwrap();
    assert!(p.root.join("rust/ads-rust/ran-marker").exists());
    assert!(!r.rows[0].stdout.contains("marked"));
}

#[test]
fn a_failing_warm_up_refuses() {
    let mut p = Planted::new("warm");
    p.row("w", "cargo ok\n");
    let mut c = cfg(&p);
    c.warm = vec![vec!["cargo".into(), "fail".into()]];
    let e = emit(&c).unwrap_err();
    assert_eq!(codes(&e), ["E-WARM"]);
    assert!(!p.out.exists());
}

// ---- execution: the real status is recorded and a failure is never a zero ----

#[test]
fn a_failing_command_refuses_with_its_row_line_and_real_exit_code()
{
    let mut p = Planted::new("fail");
    p.row("f1", "cargo ok\ncargo fail\ncargo ok\n");
    let e = refused(&p, "E-STATUS");
    let m = &e[0].msg;
    assert!(
        m.contains("term-f1")
            && m.contains("line 2")
            && m.contains("exit 3"),
        "{m}"
    );
}

#[test]
fn a_failing_command_stops_the_session_at_that_line() {
    let mut p = Planted::new("stop");
    p.row("s", "cargo fail\ncargo marker\n");
    refused(&p, "E-STATUS");
    assert!(!p.root.join("rust/ads-rust/ran-marker").exists());
}

#[test]
fn death_by_signal_refuses_and_is_never_a_zero() {
    let mut p = Planted::new("sig");
    p.row("s", "cargo sig\n");
    let e = refused(&p, "E-STATUS");
    assert!(e[0].msg.contains("signal 9"), "{}", e[0].msg);
}

#[test]
fn a_program_that_cannot_be_spawned_refuses_and_is_not_a_row() {
    let mut p = Planted::new("spawn");
    p.row("s", "bat x\n");
    let mut c = cfg(&p);
    c.host.path = Some(format!(
        "{}",
        Scratch::new("emptybin").path().display()
    ));
    let e = emit(&c).unwrap_err();
    assert!(codes(&e).contains(&"E-SPAWN"), "{e:?}");
    assert!(!p.out.exists());
}

#[test]
fn a_command_past_the_timeout_refuses() {
    let mut p = Planted::new("slow");
    p.row("s", "cargo slow\n");
    let mut c = cfg(&p);
    c.timeout = Duration::from_secs(1);
    let e = emit(&c).unwrap_err();
    assert!(codes(&e).contains(&"E-TIMEOUT"), "{e:?}");
    assert!(!p.out.exists());
}

#[test]
fn output_that_is_not_utf8_refuses() {
    let mut p = Planted::new("utf");
    p.row("u", "cargo badutf8\n");
    refused(&p, "E-UTF8");
}

#[test]
fn cargo_test_facts_are_enforced() {
    for variant in ["failed", "ignored", "zero", "none"] {
        let mut p = Planted::new("tests");
        p.row("t", &format!("cargo test {variant}\n"));
        refused(&p, "E-TESTS");
    }
}

#[test]
fn leaks_refuse() {
    for v in ["leakhome", "leakhex", "leakabs"] {
        let mut p = Planted::new("leak");
        p.row("l", &format!("cargo {v}\n"));
        refused(&p, "E-LEAK");
    }
}

#[test]
fn a_refusal_in_a_later_row_leaves_no_file_and_removes_a_stale_one()
{
    let mut p = Planted::new("atomic");
    p.row("aaa", "cargo ok\n");
    p.row("bbb", "cargo fail\n");
    fs::write(&p.out, "stale").unwrap();
    let e = emit(&cfg(&p)).unwrap_err();
    assert!(codes(&e).contains(&"E-STATUS"));
    assert!(!p.out.exists());
    assert!(!p.out.with_extension("json.tmp").exists());
}

// ---- input guards ----

#[test]
fn no_row_files_refuses() {
    let p = Planted::new("none");
    refused(&p, "E-INPUT");
}

#[test]
fn a_missing_env_file_refuses() {
    let mut p = Planted::new("noenv");
    p.row("a", "cargo ok\n");
    fs::remove_file(p.term.join("env")).unwrap();
    refused(&p, "E-INPUT");
}

#[test]
fn ids_outside_a_to_z_0_to_9_refuse_whatever_the_locale() {
    for bad in
        ["Abc123", "GGGGGGGGGG", "é1", "a.b", "a-b", "a_b", "ａ"]
    {
        let mut p = Planted::new("id");
        p.row("ok1", "cargo ok\n");
        fs::write(p.term.join(format!("{bad}.cmds")), "cargo ok\n")
            .unwrap();
        refused(&p, "E-ID");
    }
}

#[test]
fn an_empty_command_file_refuses() {
    let mut p = Planted::new("empty");
    p.row("e", "");
    refused(&p, "E-EMPTY");
}

#[test]
fn a_line_outside_the_closed_form_refuses_naming_file_and_line() {
    for bad in [
        "cargo ok; cargo fail\n",
        "cargo ok\ncargo $(false)\n",
        "cargo ok &\n",
        "cargo ok | cat\n",
        "cargo ok\n\ncargo ok\n",
        "FOO=1 cargo ok\n",
        "sh -c x\n",
        "cargo 'ok'\n",
        "cargo ok > x\n",
        "cargo ok # c\n",
        "cargo ok\\\n",
        "cargo é\n",
    ] {
        let mut p = Planted::new("form");
        p.row("f1", bad);
        let e = refused(&p, "E-FORM");
        assert!(e[0].msg.contains("f1.cmds:"), "{}", e[0].msg);
    }
}

#[test]
fn a_form_refusal_runs_nothing() {
    let mut p = Planted::new("formrun");
    p.row("a", "cargo marker\n");
    p.row("b", "cargo ok; cargo ok\n");
    refused(&p, "E-FORM");
    assert!(!p.root.join("rust/ads-rust/ran-marker").exists());
}

#[test]
fn an_unlisted_row_file_refuses() {
    let mut p = Planted::new("unlisted");
    p.row("a", "cargo ok\n");
    fs::write(p.term.join("b.cmds"), "cargo ok\n").unwrap();
    fs::write(p.term.join("b.cwd"), "rust/ads-rust\n").unwrap();
    let e = refused(&p, "E-ROWS");
    assert!(e[0].msg.contains("b.cmds"), "{}", e[0].msg);
}

#[test]
fn a_listed_row_with_a_missing_file_refuses() {
    let mut p = Planted::new("missing");
    p.row("a", "cargo ok\n");
    fs::remove_file(p.term.join("a.cwd")).unwrap();
    refused(&p, "E-ROWS");
    let mut q = Planted::new("missing2");
    q.row("a", "cargo ok\n");
    fs::remove_file(q.term.join("a.cmds")).unwrap();
    refused(&q, "E-ROWS");
}

#[test]
fn a_sha_mismatch_refuses_for_cmds_and_cwd() {
    let mut p = Planted::new("sha");
    p.row("a", "cargo ok\n");
    fs::write(p.term.join("a.cmds"), "cargo fail\n").unwrap();
    refused(&p, "E-ROWS");
    let mut q = Planted::new("sha2");
    q.row("a", "cargo ok\n");
    fs::create_dir_all(q.root.join("rust/other")).unwrap();
    fs::write(q.term.join("a.cwd"), "rust/other\n").unwrap();
    refused(&q, "E-ROWS");
}

#[test]
fn a_malformed_or_duplicate_rows_list_line_refuses() {
    let mut p = Planted::new("rl");
    p.row("a", "cargo ok\n");
    let good =
        fs::read_to_string(p.term.join("rows.list")).unwrap();
    for bad in [
        format!("{good}garbage\n"),
        format!(
            "{good}{}",
            good.lines().nth(1).unwrap().to_string() + "\n"
        ),
        good.replace("a ", "a  "),
        good.replace('a', "A"),
        format!(
            "{good}a {} {} # tail\n",
            "0".repeat(64),
            "0".repeat(64)
        ),
    ] {
        fs::write(p.term.join("rows.list"), bad).unwrap();
        refused(&p, "E-ROWS");
    }
}

#[test]
fn a_missing_rows_list_refuses() {
    let mut p = Planted::new("norl");
    p.row("a", "cargo ok\n");
    fs::remove_file(p.term.join("rows.list")).unwrap();
    refused(&p, "E-ROWS");
}

#[test]
fn an_unexpected_file_in_the_row_directory_refuses() {
    for name in ["notes.txt", "a.sh", "a.cmds.bak"] {
        let mut p = Planted::new("extra");
        p.row("a", "cargo ok\n");
        fs::write(p.term.join(name), "x").unwrap();
        refused(&p, "E-ROWS");
    }
}

#[test]
fn a_bad_cwd_refuses() {
    for (tag, cwd) in [
        ("abs", "/etc\n"),
        ("dotdot", "../x\n"),
        ("missing", "rust/nope\n"),
        ("empty", "\n"),
        ("two", "rust\nrust\n"),
    ] {
        let mut p = Planted::new(tag);
        p.row("a", "cargo ok\n");
        fs::write(p.term.join("a.cwd"), cwd).unwrap();
        p.write_rows_list();
        refused(&p, "E-CWD");
    }
}

#[test]
fn a_cwd_symlink_out_of_the_repo_refuses() {
    let mut p = Planted::new("sym");
    p.row("a", "cargo ok\n");
    let outside = Scratch::new("outside");
    std::os::unix::fs::symlink(
        outside.path(),
        p.root.join("rust/escape"),
    )
    .unwrap();
    fs::write(p.term.join("a.cwd"), "rust/escape\n").unwrap();
    p.write_rows_list();
    refused(&p, "E-CWD");
}

#[test]
fn an_env_file_key_outside_the_list_refuses() {
    for line in
        ["PATH=/x", "LD_PRELOAD=/x", "HOME=/x", "RUSTFLAGS=-Cx"]
    {
        let mut p = Planted::new("env");
        p.row("a", "cargo ok\n");
        fs::write(p.term.join("env"), format!("TERM=x\n{line}\n"))
            .unwrap();
        refused(&p, "E-ENV");
    }
}

#[test]
fn a_relative_target_dir_refuses() {
    let mut p = Planted::new("tgt");
    p.row("a", "cargo ok\n");
    let mut c = cfg(&p);
    c.target_dir = "rel/target".into();
    let e = emit(&c).unwrap_err();
    assert!(
        codes(&e).contains(&"E-INPUT")
            || codes(&e).contains(&"E-ENV"),
        "{e:?}"
    );
    assert!(!p.out.exists());
}

#[test]
fn validate_runs_nothing_and_returns_the_plan() {
    let mut p = Planted::new("plan");
    p.row("a", "cargo marker\n");
    let plan = validate(&cfg(&p)).unwrap();
    assert_eq!(plan.len(), 1);
    assert_eq!(plan[0].id, "a");
    assert_eq!(plan[0].lines.len(), 1);
    assert!(!p.root.join("rust/ads-rust/ran-marker").exists());
    assert!(!p.out.exists());
}

/// A row whose only gate line is `make <target>` at the checkout root.
fn gate_row(target: &str, out: &str) -> Planted {
    let mut p = Planted::new("make");
    p.row_in(
        "gg1",
        &format!("bat -r 1:2 src/x.rs\nmake {target}\n"),
        ".\n",
    );
    fs::write(p.root.join("make-out"), out).unwrap();
    p
}

#[test]
fn a_make_gate_row_runs_at_the_checkout_root_with_the_root_normalised()
 {
    for t in ["gate-shacl", "gate-rust"] {
        let p = gate_row(t, "shacl OK\n");
        let r = emit(&cfg(&p)).unwrap();
        assert_eq!(
            r.rows[0].commands,
            ["bat -r 1:2 src/x.rs", format!("make {t}").as_str()]
        );
        assert!(
            r.rows[0].stdout.contains(&format!(
                "$ make {t}\nran {t} in .\nshacl OK\n"
            )),
            "{}",
            r.rows[0].stdout
        );
    }
}

#[test]
fn a_changed_gate_output_line_changes_the_row_digest() {
    let a = emit(&cfg(&gate_row("gate-rust", "rust gate OK\n")))
        .unwrap();
    let b = emit(&cfg(&gate_row("gate-rust", "rust gate OK\n")))
        .unwrap();
    let c =
        emit(&cfg(&gate_row("gate-rust", "rust gate FAIL-ish\n")))
            .unwrap();
    assert_eq!(a.rows[0].stdout_sha256, b.rows[0].stdout_sha256);
    assert_ne!(a.rows[0].stdout_sha256, c.rows[0].stdout_sha256);
}

#[test]
fn a_gate_run_that_prints_a_host_path_or_hex_run_is_refused() {
    let p = gate_row("gate-shacl", "/home/someone/x.ttl\n");
    refused(&p, "E-LEAK");
    let p = gate_row("gate-rust", "id 0123456789abcdef0123\n");
    refused(&p, "E-LEAK");
}

#[test]
fn a_make_row_with_any_other_target_is_refused_before_anything_runs()
 {
    for bad in ["gate-pmat", "-C rust gate-rust", ""] {
        let mut p = Planted::new("makebad");
        p.row_in("gg2", &format!("make {bad}\n"), ".\n");
        refused(&p, "E-FORM");
    }
}

#[test]
fn make_is_refused_when_the_configured_allow_list_lacks_it() {
    let p = gate_row("gate-rust", "");
    let mut c = cfg(&p);
    c.allow = vec!["bat".into(), "cargo".into()];
    let e = validate(&c).expect_err("make accepted without allow");
    assert!(codes(&e).contains(&"E-FORM"), "{e:?}");
}

#[test]
fn a_failing_make_gate_is_a_status_refusal_naming_the_line() {
    let mut p = Planted::new("makefail");
    p.row_in("gg3", "make gate-rust\n", ".\n");
    script_fail(&p);
    let e = refused(&p, "E-STATUS");
    assert!(e[0].msg.contains("line 1 `make gate-rust`"), "{e:?}");
}

fn script_fail(p: &Planted) {
    common::script(&p.bin, "make", "echo boom 1>&2; exit 2");
}
