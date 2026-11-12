//! Running one argv: no shell, a cleared environment, null stdin, one
//! merged output pipe, a watchdog that kills the whole process group.
use std::io::Read;
use std::os::unix::fs::PermissionsExt;
use std::os::unix::process::{CommandExt, ExitStatusExt};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, Instant};

/// How long to wait for the pipe to close after a kill.
const GRACE: Duration = Duration::from_secs(10);

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Exit {
    Code(i32),
    Signal(i32),
    TimedOut,
}

impl Exit {
    pub fn is_success(&self) -> bool {
        *self == Exit::Code(0)
    }

    /// A status that is never 0 unless the command exited 0.
    pub fn status_code(&self) -> i32 {
        match self {
            Exit::Code(c) => *c,
            Exit::Signal(s) => 128 + *s,
            Exit::TimedOut => 124,
        }
    }

    pub fn describe(&self) -> String {
        match self {
            Exit::Code(c) => format!("exit {c}"),
            Exit::Signal(s) => format!("killed by signal {s}"),
            Exit::TimedOut => "timed out".to_string(),
        }
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

impl std::fmt::Display for ExecError {
    fn fmt(
        &self,
        f: &mut std::fmt::Formatter<'_>,
    ) -> std::fmt::Result {
        match self {
            ExecError::NotFound(m) => write!(f, "not found: {m}"),
            ExecError::Spawn(m) => write!(f, "cannot start: {m}"),
            ExecError::Io(m) => write!(f, "i/o: {m}"),
        }
    }
}

/// The first executable regular file called `name` in an absolute
/// search directory. A relative entry is never searched.
pub fn resolve_program(
    name: &str,
    search: &[PathBuf],
) -> Result<PathBuf, ExecError> {
    if name.is_empty() || name.contains('/') || name.contains('\0')
    {
        return Err(ExecError::NotFound(format!(
            "odd name {name:?}"
        )));
    }
    for dir in search.iter().filter(|d| d.is_absolute()) {
        let cand = dir.join(name);
        if let Ok(m) = std::fs::metadata(&cand)
            && m.is_file()
            && m.permissions().mode() & 0o111 != 0
        {
            return Ok(cand);
        }
    }
    Err(ExecError::NotFound(name.to_string()))
}

/// Kill the process group led by `pid`; fall back to the leader alone.
fn kill_group(pid: u32) {
    for tool in ["/usr/bin/kill", "/bin/kill"] {
        if !Path::new(tool).exists() {
            continue;
        }
        for target in [format!("-{pid}"), pid.to_string()] {
            let ok = Command::new(tool)
                .env_clear()
                .args(["-KILL", "--", &target])
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status()
                .is_ok_and(|s| s.success());
            if ok {
                return;
            }
        }
    }
}

fn exit_of(s: std::process::ExitStatus) -> Exit {
    match (s.code(), s.signal()) {
        (Some(c), _) => Exit::Code(c),
        (None, Some(sig)) => Exit::Signal(sig),
        (None, None) => Exit::Code(-1),
    }
}

/// `ETXTBSY`: a sibling thread forked while this program's file was
/// still open for writing. The window closes in microseconds, so a
/// short bounded retry is the whole remedy.
const TEXT_FILE_BUSY: i32 = 26;

fn spawn_retry(
    cmd: &mut Command,
) -> std::io::Result<std::process::Child> {
    let mut tries = 0;
    loop {
        match cmd.spawn() {
            Err(e)
                if e.raw_os_error() == Some(TEXT_FILE_BUSY)
                    && tries < 20 =>
            {
                tries += 1;
                thread::sleep(Duration::from_millis(25));
            }
            other => return other,
        }
    }
}

/// Run `program` with `args` in `cwd` with exactly `env`. Stdout and
/// stderr share one pipe, so their order is the order they were written.
pub fn run(
    program: &Path,
    args: &[String],
    cwd: &Path,
    env: &[(String, String)],
    timeout: Duration,
) -> Result<Outcome, ExecError> {
    let (mut reader, writer) = std::io::pipe()
        .map_err(|e| ExecError::Io(e.to_string()))?;
    let writer2 = writer
        .try_clone()
        .map_err(|e| ExecError::Io(e.to_string()))?;
    let mut cmd = Command::new(program);
    cmd.args(args)
        .current_dir(cwd)
        .env_clear()
        .envs(env.iter().map(|(k, v)| (k.as_str(), v.as_str())))
        .stdin(Stdio::null())
        .stdout(writer)
        .stderr(writer2)
        .process_group(0);
    let mut child = spawn_retry(&mut cmd).map_err(|e| {
        ExecError::Spawn(format!("{}: {e}", program.display()))
    })?;
    // The Command still holds the parent's copies of the write end.
    drop(cmd);
    let pid = child.id();
    let start = Instant::now();

    let (st_tx, st_rx) = mpsc::channel();
    thread::spawn(move || {
        let _ = st_tx.send(child.wait());
    });
    let (out_tx, out_rx) = mpsc::channel();
    thread::spawn(move || {
        let mut buf = Vec::new();
        let r = reader.read_to_end(&mut buf);
        let _ = out_tx.send(r.map(|_| buf));
    });

    let status = match st_rx.recv_timeout(timeout) {
        Ok(s) => Some(s.map_err(|e| ExecError::Io(e.to_string()))?),
        Err(mpsc::RecvTimeoutError::Timeout) => {
            kill_group(pid);
            let _ = st_rx.recv_timeout(GRACE);
            None
        }
        Err(mpsc::RecvTimeoutError::Disconnected) => {
            return Err(ExecError::Io("waiter thread died".into()));
        }
    };
    let Some(status) = status else {
        let output = out_rx
            .recv_timeout(GRACE)
            .ok()
            .and_then(Result::ok)
            .unwrap_or_default();
        return Ok(Outcome {
            exit: Exit::TimedOut,
            output,
        });
    };
    // The leader is gone; a child that still holds the pipe is a leak.
    let left = timeout.saturating_sub(start.elapsed());
    match out_rx.recv_timeout(left.max(Duration::from_secs(1))) {
        Ok(Ok(output)) => Ok(Outcome {
            exit: exit_of(status),
            output,
        }),
        Ok(Err(e)) => Err(ExecError::Io(e.to_string())),
        Err(_) => {
            kill_group(pid);
            let output = out_rx
                .recv_timeout(GRACE)
                .ok()
                .and_then(Result::ok)
                .unwrap_or_default();
            Ok(Outcome {
                exit: Exit::TimedOut,
                output,
            })
        }
    }
}
