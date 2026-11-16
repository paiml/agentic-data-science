//! `demo-emit [--root DIR] [--term-dir DIR] [--no-warm] [--timeout-s N] OUT.json`
use demo_emit::emit::{Config, emit};
use demo_emit::env::Host;
use demo_emit::exec::{resolve_program, run};
use std::ffi::OsString;
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::time::Duration;

const USAGE: &str = "usage: demo-emit [--root DIR] [--term-dir DIR] [--no-warm] [--timeout-s N] OUT.json";

fn usage(msg: &str) -> ExitCode {
    eprintln!("demo-emit: {msg}\n{USAGE}");
    ExitCode::from(2)
}

fn var(k: &str) -> Option<String> {
    std::env::var(k).ok().filter(|v| !v.is_empty())
}

fn hex40(s: &str) -> bool {
    s.len() == 40 && s.bytes().all(|b| b.is_ascii_hexdigit())
}

fn git_head(root: &Path, host: &Host) -> String {
    let search: Vec<PathBuf> = host
        .path
        .iter()
        .flat_map(|p| p.split(':'))
        .map(PathBuf::from)
        .collect();
    let Ok(git) = resolve_program("git", &search) else {
        return "unknown".into();
    };
    let env = vec![
        ("PATH".to_string(), host.path.clone().unwrap_or_default()),
        ("GIT_CONFIG_NOSYSTEM".into(), "1".into()),
        ("GIT_CONFIG_GLOBAL".into(), "/dev/null".into()),
    ];
    let args = vec![
        "-c".to_string(),
        format!("safe.directory={}", root.display()),
        "rev-parse".into(),
        "HEAD".into(),
    ];
    match run(&git, &args, root, &env, Duration::from_secs(30)) {
        Ok(o) if o.exit.is_success() => {
            let t = String::from_utf8_lossy(&o.output)
                .trim()
                .to_string();
            if hex40(&t) { t } else { "unknown".into() }
        }
        _ => "unknown".into(),
    }
}

struct Args {
    root: Option<PathBuf>,
    term: Option<PathBuf>,
    warm: bool,
    timeout: u64,
    out: PathBuf,
}

fn value(
    it: &mut impl Iterator<Item = OsString>,
    flag: &str,
) -> Result<OsString, String> {
    it.next().ok_or_else(|| format!("{flag} needs a value"))
}

fn parse_args(
    mut it: impl Iterator<Item = OsString>,
) -> Result<Args, String> {
    let mut a = Args {
        root: None,
        term: None,
        warm: true,
        timeout: 2400,
        out: PathBuf::new(),
    };
    let mut out: Option<PathBuf> = None;
    while let Some(arg) = it.next() {
        match arg.to_str() {
            Some("--root") => {
                a.root = Some(value(&mut it, "--root")?.into())
            }
            Some("--term-dir") => {
                a.term = Some(value(&mut it, "--term-dir")?.into())
            }
            Some("--no-warm") => a.warm = false,
            Some("--timeout-s") => {
                a.timeout = value(&mut it, "--timeout-s")?
                    .to_str()
                    .and_then(|v| v.parse::<u64>().ok())
                    .filter(|n| *n > 0)
                    .ok_or(
                        "--timeout-s needs a positive integer",
                    )?;
            }
            Some(f) if f.starts_with("--") => {
                return Err(format!("unknown option {f}"));
            }
            _ => {
                if out.replace(PathBuf::from(arg)).is_some() {
                    return Err("exactly one output path".into());
                }
            }
        }
    }
    a.out = out.ok_or("missing output path")?;
    Ok(a)
}

fn target_dir(root: &Path) -> Result<PathBuf, String> {
    let target = match var("CARGO_TARGET_DIR") {
        Some(t) => {
            let t = t.trim_end_matches('/');
            PathBuf::from(if t.is_empty() { "/" } else { t })
        }
        None => root.join("rust/ads-rust/target"),
    };
    if !target.is_absolute() {
        return Err(
            "CARGO_TARGET_DIR must be an absolute path".into()
        );
    }
    std::fs::create_dir_all(&target).map_err(|e| {
        format!("CARGO_TARGET_DIR {}: {e}", target.display())
    })?;
    Ok(target)
}

fn commit_of(root: &Path, host: &Host) -> Result<String, String> {
    match var("GITHUB_SHA") {
        Some(s) if hex40(&s) => Ok(s.to_ascii_lowercase()),
        Some(_) => Err("GITHUB_SHA must be 40 hex digits".into()),
        None => Ok(git_head(root, host)),
    }
}

fn warm_argv() -> Vec<Vec<String>> {
    let v = |a: &[&str]| a.iter().map(|s| s.to_string()).collect();
    vec![
        v(&["cargo", "test", "--locked", "--offline", "--no-run"]),
        v(&[
            "cargo",
            "build",
            "--locked",
            "--offline",
            "--examples",
        ]),
    ]
}

fn build_config(a: Args) -> Result<Config, String> {
    let cwd = std::env::current_dir().map_err(|_| {
        "cannot read the current directory".to_string()
    })?;
    let root = cwd.join(a.root.unwrap_or_else(|| cwd.clone()));
    let root = std::fs::canonicalize(&root).map_err(|_| {
        format!("--root {}: not a directory", root.display())
    })?;
    let term_dir = match a.term {
        Some(t) => cwd.join(t),
        None => root.join("rust/term-demos"),
    };
    let host = Host {
        path: var("PATH"),
        home: var("HOME"),
        cargo_home: var("CARGO_HOME"),
        rustup_home: var("RUSTUP_HOME"),
    };
    let work_parent = var("RUNNER_TEMP")
        .or_else(|| var("TMPDIR"))
        .unwrap_or_else(|| "/tmp".into());
    Ok(Config {
        target_dir: target_dir(&root)?,
        commit: commit_of(&root, &host)?,
        out: cwd.join(&a.out),
        allow: demo_emit::parse::ALLOWED_PROGRAMS
            .iter()
            .map(|s| s.to_string())
            .collect(),
        warm: if a.warm { warm_argv() } else { vec![] },
        warm_cwd: "rust/ads-rust".into(),
        timeout: Duration::from_secs(a.timeout),
        work_parent: PathBuf::from(work_parent),
        workflow: var("GITHUB_WORKFLOW")
            .unwrap_or_else(|| "local".into()),
        run_id: var("GITHUB_RUN_ID")
            .unwrap_or_else(|| "local".into()),
        root,
        term_dir,
        host,
    })
}

fn main() -> ExitCode {
    let cfg = match parse_args(std::env::args_os().skip(1))
        .and_then(build_config)
    {
        Ok(c) => c,
        Err(m) => return usage(&m),
    };
    match emit(&cfg) {
        Ok(r) => {
            println!(
                "OK {} rows -> {}",
                r.rows.len(),
                cfg.out.display()
            );
            ExitCode::SUCCESS
        }
        Err(errs) => {
            for e in errs {
                eprintln!("FAIL {} {}", e.code, e.msg);
            }
            ExitCode::from(1)
        }
    }
}
