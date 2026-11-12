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

pub fn parse_env_file(
    _text: &str,
) -> Result<Vec<(String, String)>, EnvError> {
    todo!("RED")
}

pub fn session_env(
    _file: &[(String, String)],
    _host: &Host,
    _target: &Path,
    _root: &Path,
    _home: &Path,
) -> Result<SessionEnv, EnvError> {
    todo!("RED")
}

/// `text` is the content of `<id>.cwd`; the result is the absolute, canonical directory.
pub fn check_cwd(
    _root: &Path,
    _text: &str,
) -> Result<PathBuf, EnvError> {
    todo!("RED")
}
