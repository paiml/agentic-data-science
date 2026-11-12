//! The emitter: validate everything, run the rows, write demo.json atomically.
use crate::env::Host;
use std::path::PathBuf;
use std::time::Duration;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Refusal {
    pub code: &'static str,
    pub msg: String,
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
    pub lines: Vec<crate::parse::Line>,
    pub cwd: PathBuf,
}

/// The validation phase: every input is checked and no command runs.
pub fn validate(
    _cfg: &Config,
) -> Result<Vec<RowPlan>, Vec<Refusal>> {
    todo!("RED")
}

pub fn emit(_cfg: &Config) -> Result<Report, Vec<Refusal>> {
    todo!("RED")
}
