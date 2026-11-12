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
    assert_eq!(plan.len(), 20);
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

// ---- demos/rust-native/*.batch: every row's source slice must contain its own emphasis patterns ----

/// One compiled emphasis pattern: literal characters, where `None` is the unescaped `.` (any one character).
type Pat = Vec<Option<char>>;

/// The smallest matcher that covers the committed patterns: literal text, `.` for any character and
/// a backslash before punctuation for that literal character. Every other construct is an error.
fn compile(p: &str) -> Result<Pat, String> {
    if p.is_empty() {
        return Err("empty pattern".into());
    }
    let mut out = Vec::new();
    let mut it = p.chars();
    while let Some(c) = it.next() {
        match c {
            '\\' => match it.next() {
                Some(e) if e.is_ascii_punctuation() => {
                    out.push(Some(e))
                }
                other => {
                    return Err(format!(
                        "unsupported escape \\{} in {p:?}",
                        other.map(String::from).unwrap_or_default()
                    ));
                }
            },
            '.' => out.push(None),
            '*' | '+' | '?' | '(' | ')' | '[' | ']' | '{' | '}'
            | '|' | '^' | '$' => {
                return Err(format!(
                    "unsupported regex construct {c:?} in {p:?}"
                ));
            }
            c => out.push(Some(c)),
        }
    }
    Ok(out)
}

fn line_matches(pat: &Pat, line: &str) -> bool {
    let cs: Vec<char> = line.chars().collect();
    if pat.len() > cs.len() {
        return false;
    }
    (0..=cs.len() - pat.len()).any(|s| {
        pat.iter()
            .zip(&cs[s..])
            .all(|(p, c)| p.is_none_or(|x| x == *c))
    })
}

const FIELDS: usize = 12;

/// `cargo (run|test) --locked --offline (--example|--test) NAME`
fn is_native_run(run: &str) -> bool {
    let t: Vec<&str> = run.split(' ').collect();
    let name_ok = |n: &str| {
        !n.is_empty()
            && n.bytes().all(|b| {
                b.is_ascii_alphanumeric() || b == b'-' || b == b'_'
            })
    };
    t.len() == 6
        && t[0] == "cargo"
        && t[2] == "--locked"
        && t[3] == "--offline"
        && matches!(
            (t[1], t[4]),
            ("run", "--example") | ("test", "--test")
        )
        && name_ok(t[5])
}

/// `cd "${ADS_ROOT:?}" && make gate-NAME`: the one non-cargo form (README: gate rows).
fn is_gate_run(run: &str) -> bool {
    run.strip_prefix("cd \"${ADS_ROOT:?}\" && make gate-")
        .is_some_and(|n| {
            !n.is_empty()
                && n.bytes()
                    .all(|b| b.is_ascii_lowercase() || b == b'-')
        })
}

fn bad_run(at: &str, run: &str, wait: &str) -> Vec<String> {
    let mut bad = Vec::new();
    if !(run.is_empty() || is_native_run(run) || is_gate_run(run)) {
        bad.push(format!(
            "{at}: RUN {run:?} is neither empty, native nor a gate row"
        ));
    }
    if wait.is_empty() {
        bad.push(format!("{at}: WAIT is empty"));
    }
    bad
}

/// The source file's lines; a gate row resolves from the repository root, every other row from `rust/ads-rust`.
fn source_lines(
    f: &[&str],
    root: &std::path::Path,
) -> Result<Vec<String>, String> {
    let base = if is_gate_run(f[6]) {
        root.to_path_buf()
    } else {
        root.join("rust/ads-rust")
    };
    fs::read_to_string(base.join(f[3]))
        .map(|b| b.lines().map(String::from).collect())
        .map_err(|e| {
            format!(
                "source {} unreadable under {}: {e}",
                f[3],
                base.display()
            )
        })
}

fn bad_range(
    at: &str,
    f: &[&str],
    lines: &[String],
) -> Result<(usize, usize), String> {
    let (from, to) =
        match (f[4].parse::<usize>(), f[5].parse::<usize>()) {
            (Ok(a), Ok(b)) => (a, b),
            _ => {
                return Err(format!(
                    "{at}: from/to {:?}/{:?} not integers",
                    f[4], f[5]
                ));
            }
        };
    if from < 1 || to < from || to > lines.len() {
        return Err(format!(
            "{at}: range {from}..{to} outside 1..={} of {}",
            lines.len(),
            f[3]
        ));
    }
    Ok((from, to))
}

fn bad_patterns(
    at: &str,
    f: &[&str],
    slice: &[String],
    range: (usize, usize),
) -> Vec<String> {
    let mut bad = Vec::new();
    for (col, p) in [(9, f[8]), (10, f[9])] {
        match compile(p) {
            Err(e) => bad.push(format!("{at}: column {col}: {e}")),
            Ok(pat) => {
                if !slice.iter().any(|l| line_matches(&pat, l)) {
                    bad.push(format!(
                        "{at}: column {col} {p:?} not in {}:{}..{}",
                        f[3], range.0, range.1
                    ));
                }
            }
        }
    }
    bad
}

fn bad_row(
    at: &str,
    line: &str,
    root: &std::path::Path,
) -> Vec<String> {
    let f: Vec<&str> = line.split('|').collect();
    if f.len() != FIELDS {
        return vec![format!(
            "{at}: {} fields, want {FIELDS}",
            f.len()
        )];
    }
    let mut bad = bad_run(at, f[6], f[7]);
    let lines = match source_lines(&f, root) {
        Ok(l) => l,
        Err(e) => {
            bad.push(format!("{at}: {e}"));
            return bad;
        }
    };
    match bad_range(at, &f, &lines) {
        Ok(r) => bad.extend(bad_patterns(
            at,
            &f,
            &lines[r.0 - 1..r.1],
            r,
        )),
        Err(e) => bad.push(e),
    }
    bad
}

/// Every problem with one batch file, as `file:row: message`.
fn check_batch(
    name: &str,
    text: &str,
    root: &std::path::Path,
) -> Vec<String> {
    let mut bad: Vec<String> = text
        .lines()
        .enumerate()
        .flat_map(|(i, l)| {
            bad_row(&format!("{name}:{}", i + 1), l, root)
        })
        .collect();
    if text.lines().next().is_none() {
        bad.push(format!("{name}: no rows"));
    }
    bad
}

#[test]
fn every_batch_row_slices_the_item_that_holds_its_own_emphasis_patterns()
 {
    let root = root();
    let dir = root.join("demos/rust-native");
    let mut names: Vec<String> = fs::read_dir(&dir)
        .unwrap()
        .map(|e| e.unwrap().file_name().into_string().unwrap())
        .filter(|n| n.ends_with(".batch"))
        .collect();
    names.sort();
    assert_eq!(
        names,
        ["m1.batch", "m2.batch", "m3.batch", "m4.batch"],
        "the four module batch files"
    );
    let mut bad = Vec::new();
    for n in &names {
        let text = fs::read_to_string(dir.join(n)).unwrap();
        bad.extend(check_batch(n, &text, &root));
    }
    assert!(
        bad.is_empty(),
        "{} defects:\n{}",
        bad.len(),
        bad.join("\n")
    );
}

#[test]
fn the_readme_documents_the_gate_row_form_the_check_accepts() {
    let r = fs::read_to_string(
        root().join("demos/rust-native/README.md"),
    )
    .unwrap();
    assert!(r.contains("gate row"), "README must name gate rows");
    assert!(r.contains(r#"cd "${ADS_ROOT:?}" && make gate-NAME"#));
    assert!(r.contains("relative to the repository root"));
    assert!(r.contains("relative to `rust/ads-rust`"));
}

#[test]
fn the_batch_check_refuses_an_empty_file_a_short_row_and_a_bad_range()
 {
    let root = root();
    assert_eq!(
        check_batch("e.batch", "", &root),
        ["e.batch: no rows"]
    );
    assert!(
        check_batch("s.batch", "a|b|c\n", &root)[0]
            .contains("3 fields")
    );
    let row = |from: &str, to: &str, p1: &str| {
        format!("01|n|e|src/p1.rs|{from}|{to}||w|{p1}|fn |x|y\n")
    };
    assert!(
        check_batch("g.batch", &row("14", "20", "fn "), &root)
            .is_empty()
    );
    assert!(
        check_batch("g.batch", &row("0", "3", "fn "), &root)[0]
            .contains("outside")
    );
    assert!(
        check_batch("g.batch", &row("5", "3", "fn "), &root)[0]
            .contains("outside")
    );
    assert!(
        check_batch("g.batch", &row("1", "9999", "fn "), &root)[0]
            .contains("outside")
    );
    assert!(
        check_batch("g.batch", &row("14", "20", "zzzqqq"), &root)
            [0]
        .contains("not in")
    );
    let blank_wait = "01|n|e|src/p1.rs|1|3|||fn |fn |x|y\n";
    assert!(
        check_batch("w.batch", blank_wait, &root)[0]
            .contains("WAIT")
    );
    let bad_run = "01|n|e|src/p1.rs|1|3|ls -l|w|fn |fn |x|y\n";
    assert!(
        check_batch("r.batch", bad_run, &root)[0].contains("RUN")
    );
}

#[test]
fn the_pattern_matcher_fails_closed_on_constructs_it_does_not_know()
{
    for bad in [
        "a+", "a*", "(a)", "[ab]", "a|b", "^a", "a$", "a?", "a{2}",
        r"\d", r"\w", "a\\", "",
    ] {
        assert!(compile(bad).is_err(), "{bad:?} must be refused");
    }
    let p = compile(r"1 \+ i % 2").unwrap();
    assert!(line_matches(&p, "x 1 + i % 2 y"));
    assert!(!line_matches(&p, "1 + i % 3"));
    assert!(line_matches(
        &compile("df.filter").unwrap(),
        "df_filter"
    ));
    assert!(line_matches(
        &compile(r"pred\[i\]").unwrap(),
        "pred[i] = 1"
    ));
    assert!(line_matches(&compile(r"CP \*").unwrap(), "x CP * y"));
    assert!(!line_matches(
        &compile("longer than the line").unwrap(),
        "short"
    ));
}

#[test]
fn run_forms_are_the_documented_ones() {
    assert!(is_native_run(
        "cargo test --locked --offline --test p2"
    ));
    assert!(is_native_run(
        "cargo run --locked --offline --example a-m1-p1"
    ));
    assert!(!is_native_run(
        "cargo test --locked --offline --example p2"
    ));
    assert!(!is_native_run(
        "cargo test --locked --offline --test p1 && ls"
    ));
    assert!(!is_native_run(
        "cargo test --offline --locked --test p1"
    ));
    assert!(is_gate_run(r#"cd "${ADS_ROOT:?}" && make gate-rust"#));
    assert!(!is_gate_run(
        r#"cd "${ADS_ROOT:?}" && make gate-rust && ls"#
    ));
    assert!(!is_gate_run(r#"cd "${ADS_ROOT:?}" && make "#));
}

#[test]
fn the_two_gate_rows_are_committed_with_their_course_ids_and_the_root_cwd()
 {
    let plan = validate(&cfg()).unwrap();
    for (id, target) in
        [("c67ac635c3", "gate-shacl"), ("3efee9bb69", "gate-rust")]
    {
        let r = plan.iter().find(|r| r.id == id).expect(id);
        assert_eq!(r.cwd, root(), "{id} runs at the checkout root");
        let last = r.lines.last().unwrap();
        assert_eq!(last.program, "make");
        assert_eq!(last.args, [target]);
    }
    let makes = plan
        .iter()
        .flat_map(|r| r.lines.iter())
        .filter(|l| l.program == "make")
        .count();
    assert_eq!(makes, 2, "no other row runs make");
}
