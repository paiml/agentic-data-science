//! Running one argv: no shell, a cleared environment, null stdin, one merged output pipe.
use std::path::{Path, PathBuf};
use std::time::Duration;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Exit {
    Code(i32),
    Signal(i32),
    TimedOut,
}

impl Exit {
    pub fn is_success(&self) -> bool {
        todo!("RED")
    }
    /// A status that is never 0 unless the command exited 0.
    pub fn status_code(&self) -> i32 {
        todo!("RED")
    }
    pub fn describe(&self) -> String {
        todo!("RED")
    }
}

#[derive(Debug)]
pub struct Outcome {
    pub exit: Exit,
    pub output: Vec<u8>,
}

#[derive(Debug, PartialEq, Eq)]
pub enum ExecError {
    NotFound(String),
    Spawn(String),
    Io(String),
}

pub fn resolve_program(
    _name: &str,
    _search: &[PathBuf],
) -> Result<PathBuf, ExecError> {
    todo!("RED")
}

pub fn run(
    _program: &Path,
    _args: &[String],
    _cwd: &Path,
    _env: &[(String, String)],
    _timeout: Duration,
) -> Result<Outcome, ExecError> {
    todo!("RED")
}
