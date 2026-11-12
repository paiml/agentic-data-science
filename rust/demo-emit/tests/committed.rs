//! The committed rows against the committed emitter rules.
use demo_emit::emit::{Config, validate};
use demo_emit::env::Host;
use demo_emit::parse::ALLOWED_PROGRAMS;
use std::collections::BTreeSet;
use std::fs;
use std::path::PathBuf;
use std::time::Duration;

fn root() -> PathBuf {
    fs::canonicalize(concat!(env!("CARGO_MANIFEST_DIR"), "/../.."))
        .unwrap()
}

fn cfg() -> Config {
    let r = root();
    Config {
        root: r.clone(),
        term_dir: r.join("rust/term-demos"),
        out: std::env::temp_dir()
            .join("demo-emit-committed-never-written.json"),
        target_dir: std::env::temp_dir()
            .join("demo-emit-committed-target"),
        allow: ALLOWED_PROGRAMS
            .iter()
            .map(|s| s.to_string())
            .collect(),
        warm: vec![],
        warm_cwd: "rust/ads-rust".into(),
        timeout: Duration::from_secs(1),
        host: Host {
            path: Some("/usr/bin".into()),
            home: Some("/h".into()),
            cargo_home: None,
            rustup_home: None,
        },
        work_parent: std::env::temp_dir(),
        commit: "0".repeat(40),
        workflow: "t".into(),
        run_id: "1".into(),
    }
}

#[test]
fn every_committed_row_passes_the_validation_phase() {
    let plan = validate(&cfg()).unwrap_or_else(|e| panic!("{e:?}"));
    assert_eq!(plan.len(), 18);
    for r in &plan {
        assert!(
            r.id.bytes()
                .all(|b| b.is_ascii_lowercase()
                    || b.is_ascii_digit()),
            "{}",
            r.id
        );
    }
}

#[test]
fn the_allow_list_is_exactly_the_first_words_of_the_committed_rows()
{
    let plan = validate(&cfg()).unwrap();
    let used: BTreeSet<&str> = plan
        .iter()
        .flat_map(|r| r.lines.iter().map(|l| l.program.as_str()))
        .collect();
    let allowed: BTreeSet<&str> =
        ALLOWED_PROGRAMS.iter().copied().collect();
    assert_eq!(used, allowed);
}

#[test]
fn the_committed_rows_never_need_a_wider_alphabet_than_the_allowed_one()
 {
    // Every committed byte is in the alphabet by construction (validate passed); record the bytes actually used.
    let mut used = BTreeSet::new();
    for e in fs::read_dir(root().join("rust/term-demos")).unwrap() {
        let p = e.unwrap().path();
        if p.extension().is_some_and(|x| x == "cmds") {
            used.extend(
                fs::read(&p)
                    .unwrap()
                    .into_iter()
                    .filter(|b| *b != b'\n'),
            );
        }
    }
    for b in used {
        assert!(
            b.is_ascii_alphanumeric() || b" _./:-".contains(&b),
            "byte {b:#x}"
        );
    }
}
