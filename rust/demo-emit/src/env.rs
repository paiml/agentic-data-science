//! The session environment and the cwd rule.
use std::path::{Path, PathBuf};

/// The only keys `term-demos/env` may set.
pub const ENV_FILE_KEYS: &[&str] = &[
    "TERM",
    "PS1",
    "INPUTRC",
    "HISTFILE",
    "CARGO_INCREMENTAL",
    "BAT_PAGER",
    "BAT_STYLE",
    "BAT_THEME",
    "BAT_PAGING",
    "PAGER",
    "GIT_PAGER",
    "RUST_TEST_THREADS",
    "CARGO_TERM_PROGRESS_WHEN",
];

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EnvError(pub String);

impl std::fmt::Display for EnvError {
    fn fmt(
        &self,
        f: &mut std::fmt::Formatter<'_>,
    ) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

/// What the caller's environment gives the session.
#[derive(Debug, Clone, Default)]
pub struct Host {
    pub path: Option<String>,
    pub home: Option<String>,
    pub cargo_home: Option<String>,
    pub rustup_home: Option<String>,
}

#[derive(Debug, Clone)]
pub struct SessionEnv {
    pub vars: Vec<(String, String)>,
    pub search: Vec<PathBuf>,
}

fn err<T>(m: impl Into<String>) -> Result<T, EnvError> {
    Err(EnvError(m.into()))
}

/// One `KEY=value` line, checked against the closed key list.
fn env_line<'a>(
    n: usize,
    line: &'a str,
    seen: &[(String, String)],
) -> Result<(&'a str, &'a str), EnvError> {
    let Some((k, v)) = line.split_once('=') else {
        return err(format!("env:{n}: no '='"));
    };
    if !ENV_FILE_KEYS.contains(&k) {
        return err(format!("env:{n}: key {k:?} is not allowed"));
    }
    if !v.bytes().all(|b| (0x20..=0x7e).contains(&b)) {
        return err(format!(
            "env:{n}: value of {k} is not printable ASCII"
        ));
    }
    if seen.iter().any(|(a, _)| a == k) {
        return err(format!("env:{n}: duplicate key {k}"));
    }
    Ok((k, v))
}

/// `KEY=value` lines; `#` comment lines and empty lines are skipped.
/// Keys come from a closed list; values are printable ASCII.
pub fn parse_env_file(
    text: &str,
) -> Result<Vec<(String, String)>, EnvError> {
    let body = text.strip_suffix('\n').unwrap_or(text);
    let mut out: Vec<(String, String)> = Vec::new();
    if body.is_empty() {
        return Ok(out);
    }
    let lines = body
        .split('\n')
        .enumerate()
        .filter(|(_, l)| !l.is_empty() && !l.starts_with('#'));
    for (i, line) in lines {
        let (k, v) = env_line(i + 1, line, &out)?;
        out.push((k.to_string(), v.to_string()));
    }
    Ok(out)
}

fn absolute(what: &str, s: &str) -> Result<(), EnvError> {
    if s.starts_with('/') {
        Ok(())
    } else {
        err(format!("{what} must be an absolute path: {s:?}"))
    }
}

fn utf8<'a>(what: &str, p: &'a Path) -> Result<&'a str, EnvError> {
    match p.to_str() {
        Some(s) => Ok(s),
        None => err(format!("{what} is not UTF-8")),
    }
}

/// The whole environment a row sees: the env file, then keys this
/// program owns. Nothing else is inherited.
pub fn session_env(
    file: &[(String, String)],
    host: &Host,
    target: &Path,
    root: &Path,
    home: &Path,
) -> Result<SessionEnv, EnvError> {
    let Some(raw_path) = &host.path else {
        return err("PATH is not set");
    };
    let search: Vec<PathBuf> = raw_path
        .split(':')
        .filter(|e| e.starts_with('/'))
        .map(PathBuf::from)
        .collect();
    if search.is_empty() {
        return err("PATH has no absolute entry");
    }
    let path_var = search
        .iter()
        .map(|p| p.to_string_lossy().into_owned())
        .collect::<Vec<_>>()
        .join(":");
    let dot_home = |name: &str,
                    given: &Option<String>,
                    dir: &str| match given {
        Some(v) => absolute(name, v).map(|_| v.clone()),
        None => match &host.home {
            Some(h) => {
                absolute("HOME", h)?;
                Ok(format!("{}/{dir}", h.trim_end_matches('/')))
            }
            None => err(format!("neither {name} nor HOME is set")),
        },
    };
    let cargo_home =
        dot_home("CARGO_HOME", &host.cargo_home, ".cargo")?;
    let rustup_home =
        dot_home("RUSTUP_HOME", &host.rustup_home, ".rustup")?;
    let target_s = utf8("CARGO_TARGET_DIR", target)?;
    absolute("CARGO_TARGET_DIR", target_s)?;
    let root_s = utf8("checkout root", root)?;
    let home_s = utf8("session HOME", home)?;
    let mut vars: Vec<(String, String)> = file.to_vec();
    let mut own =
        |k: &str, v: String| vars.push((k.to_string(), v));
    own("HOME", home_s.to_string());
    own("PATH", path_var);
    own("CARGO_HOME", cargo_home);
    own("RUSTUP_HOME", rustup_home);
    own("CARGO_TARGET_DIR", target_s.to_string());
    own("LC_ALL", "C".into());
    own("TZ", "UTC".into());
    own("GIT_CONFIG_NOSYSTEM", "1".into());
    own("GIT_CONFIG_GLOBAL", "/dev/null".into());
    own("GIT_CONFIG_COUNT", "1".into());
    own("GIT_CONFIG_KEY_0", "safe.directory".into());
    own("GIT_CONFIG_VALUE_0", root_s.to_string());
    Ok(SessionEnv { vars, search })
}

fn component_ok(rel: &str, comp: &str) -> Result<(), EnvError> {
    if comp.is_empty() || comp == "." || comp == ".." {
        return err(format!("cwd {rel:?}: bad component {comp:?}"));
    }
    if !comp
        .bytes()
        .all(|b| b.is_ascii_alphanumeric() || b"_.-".contains(&b))
    {
        return err(format!(
            "cwd {rel:?}: byte outside [A-Za-z0-9_.-]"
        ));
    }
    Ok(())
}

fn canon(p: &Path, what: &str) -> Result<PathBuf, EnvError> {
    std::fs::canonicalize(p)
        .map_err(|e| EnvError(format!("{what}: {e}")))
}

/// `text` is the content of `<id>.cwd`; the result is the absolute,
/// canonical directory, which must stay inside `root`. A lone `.`
/// names the checkout root itself (the repo-level targets need it).
pub fn check_cwd(
    root: &Path,
    text: &str,
) -> Result<PathBuf, EnvError> {
    let rel = text.strip_suffix('\n').unwrap_or(text);
    if rel.is_empty() {
        return err("cwd is empty");
    }
    if rel != "." {
        rel.split('/').try_for_each(|c| component_ok(rel, c))?;
    }
    let canon_root =
        canon(root, &format!("root {}", root.display()))?;
    let dir = canon(&root.join(rel), &format!("cwd {rel:?}"))?;
    if !dir.starts_with(&canon_root) {
        return err(format!("cwd {rel:?} leaves the checkout"));
    }
    if !dir.is_dir() {
        return err(format!("cwd {rel:?} is not a directory"));
    }
    Ok(dir)
}
