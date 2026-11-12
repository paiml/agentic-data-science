//! The emitter: validate everything, run the rows, write demo.json
//! atomically. Nothing is written unless every row passed.
use crate::env::{Host, check_cwd, parse_env_file, session_env};
use crate::exec::{Exit, Outcome, resolve_program, run};
use crate::json;
use crate::normalise::{
    Roots, find_leak, is_cargo_test, normalise, strip_terminal,
    test_facts,
};
use crate::parse::{FormKind, Line, parse_cmds};
use crate::sha256::sha256_hex;
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::{Path, PathBuf};
use std::time::Duration;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Refusal {
    pub code: &'static str,
    pub msg: String,
}

fn refuse(code: &'static str, msg: impl Into<String>) -> Refusal {
    Refusal {
        code,
        msg: msg.into(),
    }
}

#[derive(Debug, Clone)]
pub struct Config {
    pub root: PathBuf,
    pub term_dir: PathBuf,
    pub out: PathBuf,
    pub target_dir: PathBuf,
    pub allow: Vec<String>,
    pub warm: Vec<Vec<String>>,
    pub warm_cwd: String,
    pub timeout: Duration,
    pub host: Host,
    pub work_parent: PathBuf,
    pub commit: String,
    pub workflow: String,
    pub run_id: String,
}

#[derive(Debug, Clone)]
pub struct Row {
    pub id: String,
    pub command: String,
    pub commands: Vec<String>,
    pub exit: i32,
    pub stdout: String,
    pub stdout_sha256: String,
}

#[derive(Debug, Clone)]
pub struct Report {
    pub rows: Vec<Row>,
}

/// One validated row: nothing has run yet.
#[derive(Debug, Clone)]
pub struct RowPlan {
    pub id: String,
    pub cmds: String,
    pub lines: Vec<Line>,
    pub cwd: PathBuf,
}

fn id_ok(id: &str) -> bool {
    !id.is_empty()
        && id
            .bytes()
            .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit())
}

fn sha_ok(s: &str) -> bool {
    s.len() == 64
        && s.bytes().all(|b| {
            b.is_ascii_digit() || (b'a'..=b'f').contains(&b)
        })
}

type Pin = (String, String);

/// One `rows.list` line: `<id> <sha256 cmds> <sha256 cwd>`.
fn pin_line(
    n: usize,
    line: &str,
) -> Result<(String, Pin), Refusal> {
    let f: Vec<&str> = line.split(' ').collect();
    if f.len() == 3 && id_ok(f[0]) && sha_ok(f[1]) && sha_ok(f[2]) {
        return Ok((
            f[0].to_string(),
            (f[1].to_string(), f[2].to_string()),
        ));
    }
    Err(refuse("E-ROWS", format!("rows.list:{n}: malformed line")))
}

fn read_text(path: &Path) -> Option<String> {
    String::from_utf8(fs::read(path).ok()?).ok()
}

/// `rows.list`, `#` comment lines allowed.
fn read_pins(
    path: &Path,
    errs: &mut Vec<Refusal>,
) -> BTreeMap<String, Pin> {
    let mut pins = BTreeMap::new();
    let Some(text) = read_text(path) else {
        errs.push(refuse(
            "E-ROWS",
            "rows.list is missing or not UTF-8",
        ));
        return pins;
    };
    let body = text.strip_suffix('\n').unwrap_or(&text);
    let lines = body
        .split('\n')
        .enumerate()
        .filter(|(_, l)| !l.is_empty() && !l.starts_with('#'));
    for (i, line) in lines {
        match pin_line(i + 1, line) {
            Err(r) => errs.push(r),
            Ok((id, pin)) => {
                if pins.insert(id.clone(), pin).is_some() {
                    errs.push(refuse(
                        "E-ROWS",
                        format!(
                            "rows.list:{}: duplicate id {id}",
                            i + 1
                        ),
                    ));
                }
            }
        }
    }
    pins
}

/// What the term directory holds.
#[derive(Default)]
struct Scan {
    ids: BTreeSet<String>,
    has_env: bool,
    has_pins: bool,
}

fn not_regular(name: &str) -> Refusal {
    refuse("E-ROWS", format!("{name} is not a regular file"))
}

/// File an entry under `Scan` or refuse it.
fn classify(
    name: &str,
    is_file: bool,
    scan: &mut Scan,
    errs: &mut Vec<Refusal>,
) {
    if name == "env" || name == "rows.list" {
        match (is_file, name == "env") {
            (false, _) => errs.push(not_regular(name)),
            (true, true) => scan.has_env = true,
            (true, false) => scan.has_pins = true,
        }
        return;
    }
    let stem = name
        .strip_suffix(".cmds")
        .or_else(|| name.strip_suffix(".cwd"));
    match stem {
        Some(_) if !is_file => errs.push(not_regular(name)),
        Some(id) if id_ok(id) => {
            scan.ids.insert(id.to_string());
        }
        Some(id) => errs.push(refuse(
            "E-ID",
            format!("row id {id:?} is not [a-z0-9]+"),
        )),
        None => errs.push(refuse(
            "E-ROWS",
            format!(
                "unexpected entry {name:?} in the row directory"
            ),
        )),
    }
}

fn scan_dir(
    dir: &Path,
    errs: &mut Vec<Refusal>,
) -> Result<Scan, Vec<Refusal>> {
    let rd = fs::read_dir(dir).map_err(|e| {
        vec![refuse("E-INPUT", format!("{}: {e}", dir.display()))]
    })?;
    let mut scan = Scan::default();
    for ent in rd.flatten() {
        let is_file = ent.file_type().is_ok_and(|t| t.is_file());
        match ent.file_name().to_str() {
            Some(name) => classify(name, is_file, &mut scan, errs),
            None => errs
                .push(refuse("E-ROWS", "a file name is not UTF-8")),
        }
    }
    Ok(scan)
}

/// Every `.cmds` is pinned and every pin has its files.
fn check_listing(
    ids: &BTreeSet<String>,
    pins: &BTreeMap<String, Pin>,
    errs: &mut Vec<Refusal>,
) {
    for id in ids.iter().filter(|i| !pins.contains_key(*i)) {
        errs.push(refuse(
            "E-ROWS",
            format!("{id}.cmds is not listed in rows.list"),
        ));
    }
    for id in pins.keys().filter(|i| !ids.contains(*i)) {
        errs.push(refuse(
            "E-ROWS",
            format!(
                "rows.list names {id} but its files are missing"
            ),
        ));
    }
}

fn load_env_file(
    dir: &Path,
) -> Result<Vec<(String, String)>, String> {
    let bytes =
        fs::read(dir.join("env")).map_err(|e| e.to_string())?;
    let text =
        String::from_utf8(bytes).map_err(|e| e.to_string())?;
    parse_env_file(&text).map_err(|e| e.0)
}

/// The env file and the session environment it yields.
fn check_env(cfg: &Config, errs: &mut Vec<Refusal>) {
    let home = cfg.work_parent.join("home");
    let res = load_env_file(&cfg.term_dir).and_then(|file| {
        session_env(
            &file,
            &cfg.host,
            &cfg.target_dir,
            &cfg.root,
            &home,
        )
        .map(|_| ())
        .map_err(|e| e.0)
    });
    if let Err(m) = res {
        errs.push(refuse("E-ENV", m));
    }
}

fn form_refusal(id: &str, e: &crate::parse::FormError) -> Refusal {
    if e.kind == FormKind::EmptyFile {
        return refuse("E-EMPTY", format!("{id}.cmds is empty"));
    }
    refuse("E-FORM", format!("{id}.cmds:{}: {:?}", e.line, e.kind))
}

fn check_cwd_bytes(
    root: &Path,
    bytes: Vec<u8>,
) -> Result<PathBuf, String> {
    let t = String::from_utf8(bytes)
        .map_err(|_| "not UTF-8".to_string())?;
    check_cwd(root, &t).map_err(|e| e.0)
}

/// Validate one row. A row is planned only when every check passed.
fn plan_row(
    cfg: &Config,
    allow: &[&str],
    id: &str,
    pin: &Pin,
    errs: &mut Vec<Refusal>,
) -> Option<RowPlan> {
    let cmds_b = fs::read(cfg.term_dir.join(format!("{id}.cmds")));
    let cwd_b = fs::read(cfg.term_dir.join(format!("{id}.cwd")));
    let (Ok(cmds_b), Ok(cwd_b)) = (cmds_b, cwd_b) else {
        errs.push(refuse(
            "E-ROWS",
            format!("{id}: a row file is unreadable"),
        ));
        return None;
    };
    let before = errs.len();
    for (ext, bytes, want) in
        [("cmds", &cmds_b, &pin.0), ("cwd", &cwd_b, &pin.1)]
    {
        if &sha256_hex(bytes) != want {
            errs.push(refuse(
                "E-ROWS",
                format!(
                    "{id}.{ext} does not match its rows.list pin"
                ),
            ));
        }
    }
    let lines = parse_cmds(&cmds_b, allow)
        .map_err(|e| errs.push(form_refusal(id, &e)))
        .ok()?;
    let cwd = check_cwd_bytes(&cfg.root, cwd_b)
        .map_err(|m| {
            errs.push(refuse("E-CWD", format!("{id}.cwd: {m}")))
        })
        .ok()?;
    (errs.len() == before).then(|| RowPlan {
        id: id.to_string(),
        cmds: String::from_utf8_lossy(&cmds_b).into_owned(),
        lines,
        cwd,
    })
}

/// The validation phase: every input is checked and no command runs.
pub fn validate(
    cfg: &Config,
) -> Result<Vec<RowPlan>, Vec<Refusal>> {
    let mut errs: Vec<Refusal> = Vec::new();
    let scan = scan_dir(&cfg.term_dir, &mut errs)?;
    if scan.ids.is_empty() && errs.is_empty() {
        return Err(vec![refuse("E-INPUT", "no rows found")]);
    }
    if !scan.has_env {
        errs.push(refuse("E-INPUT", "the env file is missing"));
    }
    let pins = if scan.has_pins {
        read_pins(&cfg.term_dir.join("rows.list"), &mut errs)
    } else {
        errs.push(refuse("E-ROWS", "rows.list is missing"));
        BTreeMap::new()
    };
    check_listing(&scan.ids, &pins, &mut errs);
    if scan.has_env {
        check_env(cfg, &mut errs);
    }
    if !cfg.warm.is_empty()
        && let Err(e) = check_cwd(&cfg.root, &cfg.warm_cwd)
    {
        errs.push(refuse("E-CWD", format!("warm-up cwd: {e}")));
    }
    let allow: Vec<&str> =
        cfg.allow.iter().map(String::as_str).collect();
    let plan: Vec<RowPlan> = scan
        .ids
        .iter()
        .filter_map(|id| {
            let pin = pins.get(id)?;
            plan_row(cfg, &allow, id, pin, &mut errs)
        })
        .collect();
    if errs.is_empty() { Ok(plan) } else { Err(errs) }
}

/// A scratch directory this run made; removed when dropped.
struct Work(PathBuf);

impl Drop for Work {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

fn tail(s: &str, n: usize) -> String {
    let lines: Vec<&str> = s.lines().collect();
    lines[lines.len().saturating_sub(n)..].join("\n")
}

fn remove_if_present(p: &Path) -> Result<(), Refusal> {
    match fs::remove_file(p) {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            Ok(())
        }
        Err(e) => {
            Err(refuse("E-OUT", format!("{}: {e}", p.display())))
        }
    }
}

fn tmp_of(out: &Path) -> PathBuf {
    let mut s = out.as_os_str().to_os_string();
    s.push(".tmp");
    PathBuf::from(s)
}

fn to_s(p: &Path) -> String {
    p.to_string_lossy().into_owned()
}

/// Everything a run needs once validation has passed.
struct Session {
    _work: Work,
    canon_root: PathBuf,
    vars: Vec<(String, String)>,
    search: Vec<PathBuf>,
    roots: Roots,
    leak_roots: Roots,
}

fn make_work(
    cfg: &Config,
) -> Result<(Work, PathBuf, PathBuf), Refusal> {
    let stamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_or(0, |d| d.as_nanos());
    let name = format!("demo-emit-{}-{stamp}", std::process::id());
    let work = Work(cfg.work_parent.join(name));
    let bad = |e: std::io::Error| {
        refuse("E-INPUT", format!("work dir: {e}"))
    };
    fs::create_dir(&work.0).map_err(bad)?;
    let path = fs::canonicalize(&work.0).unwrap_or(work.0.clone());
    let home = path.join("home");
    fs::create_dir(&home).map_err(bad)?;
    Ok((work, path, home))
}

fn build_roots(
    cfg: &Config,
    canon_root: &Path,
    work: &Work,
    work_path: &Path,
    home: &Path,
    vars: &[(String, String)],
) -> (Roots, Roots) {
    let mut target = vec![to_s(&cfg.target_dir)];
    if let Ok(c) = fs::canonicalize(&cfg.target_dir) {
        target.push(to_s(&c));
    }
    let root = vec![to_s(&cfg.root), to_s(canon_root)];
    let mut host: Vec<String> =
        [home, work_path, &work.0, &cfg.work_parent]
            .iter()
            .map(|p| to_s(p))
            .collect();
    host.extend(
        vars.iter()
            .filter(|(k, _)| {
                k == "CARGO_HOME" || k == "RUSTUP_HOME"
            })
            .map(|(_, v)| v.clone()),
    );
    host.extend(cfg.host.home.clone());
    let roots = Roots { target, root, host };
    let mut leak_roots = roots.clone();
    leak_roots.host.extend(roots.root.iter().cloned());
    leak_roots.host.extend(roots.target.iter().cloned());
    (roots, leak_roots)
}

fn open_session(cfg: &Config) -> Result<Session, Refusal> {
    let canon_root = fs::canonicalize(&cfg.root)
        .map_err(|e| refuse("E-INPUT", format!("root: {e}")))?;
    let (work, work_path, home) = make_work(cfg)?;
    let file = load_env_file(&cfg.term_dir)
        .map_err(|m| refuse("E-ENV", m))?;
    let senv = session_env(
        &file,
        &cfg.host,
        &cfg.target_dir,
        &canon_root,
        &home,
    )
    .map_err(|e| refuse("E-ENV", e.0))?;
    let (roots, leak_roots) = build_roots(
        cfg,
        &canon_root,
        &work,
        &work_path,
        &home,
        &senv.vars,
    );
    Ok(Session {
        _work: work,
        canon_root,
        vars: senv.vars,
        search: senv.search,
        roots,
        leak_roots,
    })
}

/// Run `argv` in `cwd`; any failure to start is `code`.
fn spawn(
    s: &Session,
    cfg: &Config,
    argv: (&str, &[String]),
    cwd: &Path,
    at: &str,
    code: &'static str,
) -> Result<Outcome, Refusal> {
    let bad = |e: &dyn std::fmt::Display| {
        refuse(code, format!("{at}: {e}"))
    };
    let exe =
        resolve_program(argv.0, &s.search).map_err(|e| bad(&e))?;
    run(&exe, argv.1, cwd, &s.vars, cfg.timeout)
        .map_err(|e| bad(&e))
}

/// Warm-up: fixed argv lists, output not recorded.
fn run_warm(cfg: &Config, s: &Session) -> Result<(), Refusal> {
    if cfg.warm.is_empty() {
        return Ok(());
    }
    let wd = check_cwd(&s.canon_root, &cfg.warm_cwd)
        .map_err(|e| refuse("E-CWD", e.0))?;
    for argv in &cfg.warm {
        let Some((prog, args)) = argv.split_first() else {
            continue;
        };
        let at = format!("`{}`", argv.join(" "));
        let o = spawn(s, cfg, (prog, args), &wd, &at, "E-WARM")?;
        if !o.exit.is_success() {
            let text =
                String::from_utf8_lossy(&o.output).into_owned();
            let shown = tail(
                &normalise(&strip_terminal(&text), &s.roots),
                20,
            );
            return Err(refuse(
                "E-WARM",
                format!("{at}: {}\n{shown}", o.exit.describe()),
            ));
        }
    }
    Ok(())
}

/// A failed line: its status and the tail of what it printed.
fn failed_line(
    o: &Outcome,
    norm: Option<&str>,
    at: &str,
) -> Refusal {
    let code = if o.exit == Exit::TimedOut {
        "E-TIMEOUT"
    } else {
        "E-STATUS"
    };
    let shown = norm.map(|n| tail(n, 20)).unwrap_or_default();
    refuse(code, format!("{at}: {}\n{shown}", o.exit.describe()))
}

/// Run one `.cmds` line and return its normalised output.
fn run_line(
    cfg: &Config,
    s: &Session,
    p: &RowPlan,
    l: &Line,
) -> Result<String, Refusal> {
    let at = format!("term-{} line {} `{}`", p.id, l.number, l.raw);
    let o = spawn(
        s,
        cfg,
        (&l.program, &l.args),
        &p.cwd,
        &at,
        "E-SPAWN",
    )?;
    let norm = String::from_utf8(o.output.clone())
        .ok()
        .map(|t| normalise(&strip_terminal(&t), &s.roots));
    if !o.exit.is_success() {
        return Err(failed_line(&o, norm.as_deref(), &at));
    }
    let mut norm = norm.ok_or_else(|| {
        refuse("E-UTF8", format!("{at}: output is not UTF-8"))
    })?;
    if !norm.is_empty() && !norm.ends_with('\n') {
        norm.push('\n');
    }
    if is_cargo_test(&l.program, &l.args)
        && let Err(why) = test_facts(&norm)
    {
        return Err(refuse("E-TESTS", format!("{at}: {why}")));
    }
    Ok(norm)
}

fn run_row(
    cfg: &Config,
    s: &Session,
    p: &RowPlan,
) -> Result<Row, Refusal> {
    let mut transcript = String::new();
    for l in &p.lines {
        let norm = run_line(cfg, s, p, l)?;
        transcript.push_str(&format!("$ {}\n{norm}", l.raw));
    }
    if let Some(leak) = find_leak(&transcript, &s.leak_roots) {
        return Err(refuse(
            "E-LEAK",
            format!(
                "term-{} transcript line {}: {}",
                p.id, leak.line, leak.reason
            ),
        ));
    }
    Ok(Row {
        id: format!("term-{}", p.id),
        command: p.cmds.clone(),
        commands: p.lines.iter().map(|l| l.raw.clone()).collect(),
        exit: 0,
        stdout_sha256: sha256_hex(transcript.as_bytes()),
        stdout: transcript,
    })
}

fn run_all(
    cfg: &Config,
    plan: &[RowPlan],
) -> Result<Report, Refusal> {
    let s = open_session(cfg)?;
    run_warm(cfg, &s)?;
    let rows = plan
        .iter()
        .map(|p| run_row(cfg, &s, p))
        .collect::<Result<Vec<_>, _>>()?;
    Ok(Report { rows })
}

pub fn emit(cfg: &Config) -> Result<Report, Vec<Refusal>> {
    let tmp = tmp_of(&cfg.out);
    remove_if_present(&cfg.out).map_err(|r| vec![r])?;
    remove_if_present(&tmp).map_err(|r| vec![r])?;
    let plan = validate(cfg)?;
    let report = run_all(cfg, &plan).map_err(|r| vec![r])?;
    write_atomic(cfg, &tmp, &report)
        .map_err(|m| vec![refuse("E-OUT", m)])?;
    Ok(report)
}

fn render(cfg: &Config, r: &Report) -> String {
    let mut s = String::from("{\n");
    let mut kv = |k: &str, v: &str| {
        s.push_str(&format!(
            "  {}: {},\n",
            json::string(k),
            json::string(v)
        ));
    };
    kv("schema", "demo-json/v1");
    kv("course", "ads-c01-rust");
    kv("commit", &cfg.commit);
    kv("workflow", &cfg.workflow);
    kv("run_id", &cfg.run_id);
    s.push_str("  \"demos\": [\n");
    for (i, row) in r.rows.iter().enumerate() {
        s.push_str("    {\n");
        s.push_str(&format!(
            "      \"id\": {},\n",
            json::string(&row.id)
        ));
        s.push_str(&format!(
            "      \"command\": {},\n",
            json::string(&row.command)
        ));
        s.push_str("      \"commands\": [\n");
        for (j, c) in row.commands.iter().enumerate() {
            let comma =
                if j + 1 < row.commands.len() { "," } else { "" };
            s.push_str(&format!(
                "        {}{comma}\n",
                json::string(c)
            ));
        }
        s.push_str("      ],\n");
        s.push_str(&format!("      \"exit\": {},\n", row.exit));
        s.push_str(&format!(
            "      \"stdout\": {},\n",
            json::string(&row.stdout)
        ));
        s.push_str(&format!(
            "      \"stdout_sha256\": {},\n",
            json::string(&row.stdout_sha256)
        ));
        s.push_str("      \"plots\": []\n");
        let comma = if i + 1 < r.rows.len() { "," } else { "" };
        s.push_str(&format!("    }}{comma}\n"));
    }
    s.push_str("  ]\n}\n");
    s
}

fn write_atomic(
    cfg: &Config,
    tmp: &Path,
    r: &Report,
) -> Result<(), String> {
    use std::io::Write;
    if let Some(parent) =
        cfg.out.parent().filter(|p| !p.as_os_str().is_empty())
    {
        fs::create_dir_all(parent)
            .map_err(|e| format!("{}: {e}", parent.display()))?;
    }
    let body = render(cfg, r);
    let mut f = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(tmp)
        .map_err(|e| format!("{}: {e}", tmp.display()))?;
    let res =
        f.write_all(body.as_bytes()).and_then(|_| f.sync_all());
    drop(f);
    if let Err(e) = res {
        let _ = fs::remove_file(tmp);
        return Err(format!("{}: {e}", tmp.display()));
    }
    fs::rename(tmp, &cfg.out).map_err(|e| {
        let _ = fs::remove_file(tmp);
        format!("{}: {e}", cfg.out.display())
    })
}
