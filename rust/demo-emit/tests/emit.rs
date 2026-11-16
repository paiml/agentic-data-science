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

// ---- staged rows: one typed command shows its source, waits for `run`, then prints the live result ----

fn staged(case: &str) -> Planted {
    let mut p = Planted::new("staged");
    p.row_in(
        "st1",
        &format!("cd rust/ads-rust\ncargo {case}\nrun\n"),
        ".\n",
    );
    p.batch("t.batch", &format!("cargo {case}"), "OK");
    p
}

#[test]
fn a_staged_row_emits_what_is_typed_and_what_the_terminal_shows() {
    let p = staged("staged");
    let r = emit(&cfg(&p)).unwrap();
    assert_eq!(
        r.rows[0].commands,
        ["cd rust/ads-rust", "cargo staged", "run"]
    );
    assert_eq!(
        r.rows[0].command,
        "cd rust/ads-rust\ncargo staged\nrun\n"
    );
    assert_eq!(
        r.rows[0].stdout,
        "$ cd rust/ads-rust\n$ cargo staged\n== source: src/x.rs 1-2 ==\nlet a = 1;\nrun\n== run ==\ntyped=run in ads-rust\n"
    );
    assert_eq!(
        r.rows[0].stdout_sha256,
        sha256_hex(r.rows[0].stdout.as_bytes())
    );
    assert_eq!(r.rows[0].exit, 0);
}

#[test]
fn cd_joins_the_row_directory_and_the_plan_holds_the_result() {
    let mut p = Planted::new("stagedcd");
    p.row_in("st2", "cd ads-rust\ncargo staged\nrun\n", "rust\n");
    p.batch("t.batch", "cargo staged", "OK");
    let plan = validate(&cfg(&p)).unwrap();
    assert_eq!(plan[0].cwd, p.root.join("rust/ads-rust"));
    let r = emit(&cfg(&p)).unwrap();
    assert!(r.rows[0].stdout.ends_with("typed=run in ads-rust\n"));
}

#[test]
fn a_cd_that_leaves_the_checkout_or_names_no_directory_is_refused_before_anything_runs()
 {
    for bad in [
        "..",
        "rust/../..",
        "nowhere",
        "/tmp",
        "rust/term-demos/env",
    ] {
        let mut p = Planted::new("stagedbadcd");
        p.row_in(
            "st3",
            &format!("cd {bad}\ncargo marker\n"),
            ".\n",
        );
        let e = refused(&p, "E-CWD");
        assert!(e[0].msg.contains("st3.cwd: cd: "), "{e:?}");
        assert!(!p.root.join("ran-marker").exists());
    }
    let mut p = Planted::new("stagedlink");
    std::os::unix::fs::symlink("/", p.root.join("out")).unwrap();
    p.row_in("st4", "cd out\ncargo marker\n", ".\n");
    refused(&p, "E-CWD");
}

#[test]
fn a_typed_line_under_output_that_is_not_two_stages_is_refused() {
    for case in ["nosource", "norun", "tworuns", "ok"] {
        let p = staged(case);
        let e = refused(&p, "E-STAGE");
        assert!(
            e[0].msg.contains(&format!("line 2 `cargo {case}`")),
            "{e:?}"
        );
    }
}

#[test]
fn a_failing_staged_command_is_a_status_refusal_with_its_real_code()
{
    let p = staged("stagedfail");
    let e = refused(&p, "E-STATUS");
    assert!(e[0].msg.contains("exit 4"), "{e:?}");
}

#[test]
fn stray_staged_words_are_form_refusals_before_anything_runs() {
    for bad in [
        "run\n",
        "bat -r 1:2 x.rs\nrun\n",
        "cargo marker\ncd rust\n",
        "cd rust ads-rust\ncargo marker\n",
        "cargo marker\nrun\nrun\n",
    ] {
        let mut p = Planted::new("stagedform");
        p.row_in("st5", bad, ".\n");
        refused(&p, "E-FORM");
        assert!(!p.root.join("ran-marker").exists());
    }
}

#[test]
fn a_staged_command_with_no_typed_line_gets_null_stdin_and_no_echo()
{
    let mut p = Planted::new("stagednull");
    p.row("st6", "cargo staged\n");
    let r = emit(&cfg(&p)).unwrap();
    assert_eq!(
        r.rows[0].stdout,
        "$ cargo staged\n== source: src/x.rs 1-2 ==\nlet a = 1;\n== run ==\ntyped= in ads-rust\n"
    );
}

#[test]
fn the_staged_make_row_types_shacl_check_then_run() {
    let mut p = Planted::new("stagedmake");
    p.row_in("st7", "make shacl-check\nrun\n", ".\n");
    let r = emit(&cfg(&p)).unwrap();
    assert_eq!(r.rows[0].commands, ["make shacl-check", "run"]);
    assert_eq!(
        r.rows[0].stdout,
        "$ make shacl-check\n== source: a.ttl 1-1 ==\nshape\nrun\n== run: make gate-shacl ==\ntyped=run\nshacl OK\n"
    );
}

#[test]
fn stage_echo_places_the_typed_line_above_the_one_run_header() {
    use demo_emit::emit::stage_echo;
    assert_eq!(
        stage_echo("== source: f 1-1 ==\nx\n== run ==\ny\n", "run")
            .as_deref(),
        Some("== source: f 1-1 ==\nx\nrun\n== run ==\ny\n")
    );
    for bad in [
        "",
        "x\n== run ==\n",
        "== run ==\ny\n",
        "== source: f 1-1 ==\nx\n",
        "== source: f 1-1 ==\n== run ==\n== run: b ==\n",
        "== source: f 1-1 ==\n== running\n",
        "== source f\n== run ==\n",
        "== source: f 1-1 ==\n== runtime ==\n",
        "== source: f 1-1 ==\n== run: ==\n",
        "== source: f 1-1 ==\n== run:  ==\n",
        "== source: f 1-1 ==\n== run x ==\n",
        "== source: f 1-1\n== run ==\n",
    ] {
        assert_eq!(stage_echo(bad, "run"), None, "{bad:?}");
    }
}

#[test]
fn a_run_header_is_exactly_one_of_the_two_documented_forms() {
    use demo_emit::emit::{is_run_header, run_stage, stage_echo};
    for yes in
        ["== run ==", "== run ==\n", "== run: make gate-shacl ==\n"]
    {
        assert!(is_run_header(yes), "{yes:?}");
    }
    for no in [
        "== runtime ==",
        "== running ==",
        "== run==",
        "== run: ==",
        "== run:  ==",
        "== run x ==",
        "== run: x",
        " == run ==",
        "== source: f 1-1 ==",
    ] {
        assert!(!is_run_header(no), "{no:?}");
    }
    // `== runtime ==` is output like any other line: the typed line
    // still goes above the one real header.
    let out =
        "== source: f 1-1 ==\n== runtime ==\n== run ==\ny\nz\n";
    assert_eq!(
        stage_echo(out, "run").as_deref(),
        Some(
            "== source: f 1-1 ==\n== runtime ==\nrun\n== run ==\ny\nz\n"
        )
    );
    assert_eq!(run_stage(out).as_deref(), Some("y\nz\n"));
    assert_eq!(
        run_stage("== source: f 1-1 ==\n== run ==\n").as_deref(),
        Some("")
    );
    assert_eq!(run_stage("== run ==\ny\n"), None);
    let p = staged("runtime");
    let r = emit(&cfg(&p)).unwrap();
    assert!(
        r.rows[0].stdout.ends_with(
            "== runtime ==\nrun\n== run ==\ntyped=run\n"
        )
    );
}

// ---- staged test rows: the batch WAIT says the run stage runs tests, and the rule of a plain `cargo test` line holds there ----

const TEST_WAIT: &str = "test result: ok.";

fn staged_tests(case: &str) -> Planted {
    let mut p = Planted::new("stagedtests");
    p.row_in(
        "tr1",
        &format!("cd rust/ads-rust\ncargo {case}\nrun\n"),
        ".\n",
    );
    p.batch("t.batch", &format!("cargo {case}"), TEST_WAIT);
    p
}

#[test]
fn a_staged_test_row_passes_on_a_result_line_with_passed_tests() {
    let p = staged_tests("stagedtests");
    let r = emit(&cfg(&p)).unwrap();
    assert!(r.rows[0].stdout.contains(
        "run\n== run ==\nrunning 1 test\ntest result: ok. 1 passed"
    ));
}

#[test]
fn a_staged_test_row_with_no_result_line_in_its_run_stage_is_refused()
 {
    // `staged` prints no result line; `stagedsrcresult` prints one in the source stage only.
    for case in ["staged", "stagedsrcresult"] {
        let p = staged_tests(case);
        let e = refused(&p, "E-TESTS");
        assert!(
            e[0].msg.contains(&format!(
                "line 2 `cargo {case}`: run stage: no `test result:` line"
            )),
            "{e:?}"
        );
    }
}

#[test]
fn a_staged_test_row_with_a_failed_test_is_refused() {
    let e = refused(&staged_tests("stagedfailed"), "E-TESTS");
    assert!(
        e[0].msg.contains("run stage: 1 test(s) failed"),
        "{e:?}"
    );
}

#[test]
fn a_staged_test_row_with_an_ignored_test_is_refused() {
    let e = refused(&staged_tests("stagedignored"), "E-TESTS");
    assert!(
        e[0].msg.contains("run stage: 1 test(s) ignored"),
        "{e:?}"
    );
}

#[test]
fn a_staged_test_row_with_no_passed_test_is_refused() {
    let e = refused(&staged_tests("stagedzero"), "E-TESTS");
    assert!(
        e[0].msg.contains("run stage: no test passed"),
        "{e:?}"
    );
}

#[test]
fn the_batch_row_decides_whether_the_run_stage_is_a_test_run() {
    // WAIT without the test-result text: the same output is accepted.
    let p = staged("stagedzero");
    assert!(emit(&cfg(&p)).is_ok());
    // Two rows name the command; one of them waits for a test result.
    let mut p = staged("stagedzero");
    p.batch("u.batch", "cargo stagedzero", TEST_WAIT);
    refused(&p, "E-TESTS");
}

#[test]
fn a_staged_cargo_command_that_no_batch_row_names_is_refused_before_it_runs()
 {
    let row = "cd rust/ads-rust\ncargo marker\nrun\n";
    // No batch directory at all.
    let mut p = Planted::new("nobatch");
    p.row_in("nb1", row, ".\n");
    let e = refused(&p, "E-BATCH");
    assert!(
        e[0].msg.contains(
            "line 2 `cargo marker`: no row of demos/rust-native/*.batch has this RUN"
        ),
        "{e:?}"
    );
    assert!(!p.root.join("rust/ads-rust/ran-marker").exists());
    // Rows for other commands, a longer RUN, and a file that is not a batch file.
    let mut p = Planted::new("otherbatch");
    p.row_in("nb2", row, ".\n");
    p.batch("t.batch", "cargo staged", TEST_WAIT);
    p.batch("t.batch", "cargo marker -q", TEST_WAIT);
    p.batch("t.txt", "cargo marker", TEST_WAIT);
    p.batch("batch", "cargo marker", TEST_WAIT);
    refused(&p, "E-BATCH");
    assert!(!p.root.join("rust/ads-rust/ran-marker").exists());
}

#[test]
fn the_staged_make_row_needs_no_batch_row() {
    let mut p = Planted::new("makenobatch");
    p.row_in("mk1", "make shacl-check\nrun\n", ".\n");
    assert!(emit(&cfg(&p)).is_ok());
}
