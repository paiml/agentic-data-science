mod common;
use common::{Scratch, script};
use demo_emit::exec::{ExecError, Exit, resolve_program, run};
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::time::{Duration, Instant};

const T: Duration = Duration::from_secs(20);

fn go(
    s: &Scratch,
    name: &str,
    body: &str,
    env: &[(String, String)],
    t: Duration,
) -> demo_emit::exec::Outcome {
    script(s.path(), name, body);
    run(&s.path().join(name), &[], s.path(), env, t).unwrap()
}

#[test]
fn records_the_real_exit_code_of_a_failing_command() {
    let s = Scratch::new("x");
    let o = go(&s, "f", "exit 3", &[], T);
    assert_eq!(o.exit, Exit::Code(3));
    assert!(!o.exit.is_success());
    assert_eq!(o.exit.status_code(), 3);
}

#[test]
fn a_command_that_exits_zero_is_success() {
    let s = Scratch::new("x");
    let o = go(&s, "ok", "echo hi", &[], T);
    assert_eq!(o.exit, Exit::Code(0));
    assert!(o.exit.is_success());
    assert_eq!(o.exit.status_code(), 0);
    assert_eq!(o.output, b"hi\n");
}

#[test]
fn death_by_signal_is_never_zero() {
    let s = Scratch::new("x");
    let o = go(&s, "k", "kill -9 $$", &[], T);
    assert_eq!(o.exit, Exit::Signal(9));
    assert!(!o.exit.is_success());
    assert_ne!(o.exit.status_code(), 0);
    assert!(o.exit.describe().contains("signal 9"));
}

#[test]
fn a_failing_command_is_never_recorded_as_zero_whatever_it_prints()
{
    let s = Scratch::new("x");
    let o =
        go(&s, "p", "echo 'exit 0'; echo end 0; exit 1", &[], T);
    assert_ne!(o.exit.status_code(), 0);
}

#[test]
fn stdout_and_stderr_share_one_ordered_pipe() {
    let s = Scratch::new("x");
    let o = go(&s, "m", "echo a; echo b 1>&2; echo c", &[], T);
    assert_eq!(String::from_utf8(o.output).unwrap(), "a\nb\nc\n");
}

#[test]
fn the_environment_is_cleared_to_exactly_the_given_variables() {
    let s = Scratch::new("x");
    let o = go(
        &s,
        "e",
        "/usr/bin/env | /usr/bin/sort",
        &[("FOO".into(), "bar".into())],
        T,
    );
    let text = String::from_utf8(o.output).unwrap();
    assert!(text.contains("FOO=bar\n"));
    for line in text.lines() {
        let k = line.split('=').next().unwrap();
        assert!(
            ["FOO", "PWD", "OLDPWD", "SHLVL", "_"].contains(&k),
            "leaked {k}"
        );
    }
}

#[test]
fn stdin_is_null() {
    let s = Scratch::new("x");
    let o = go(&s, "i", "cat; echo done", &[], T);
    assert_eq!(o.output, b"done\n");
}

#[test]
fn runs_in_the_given_cwd() {
    let s = Scratch::new("x");
    let o = go(&s, "w", "pwd -P", &[], T);
    assert_eq!(
        String::from_utf8(o.output).unwrap().trim(),
        s.path().to_str().unwrap()
    );
}

#[test]
fn a_command_past_its_timeout_is_killed() {
    let s = Scratch::new("x");
    let t0 = Instant::now();
    let o =
        go(&s, "z", "exec sleep 30", &[], Duration::from_secs(1));
    assert_eq!(o.exit, Exit::TimedOut);
    assert!(!o.exit.is_success());
    assert_ne!(o.exit.status_code(), 0);
    assert!(t0.elapsed() < Duration::from_secs(15));
}

#[test]
fn a_timeout_kills_the_children_that_hold_the_pipe() {
    let s = Scratch::new("x");
    let t0 = Instant::now();
    let o =
        go(&s, "z", "sleep 30 & wait", &[], Duration::from_secs(1));
    assert_eq!(o.exit, Exit::TimedOut);
    assert!(t0.elapsed() < Duration::from_secs(15));
}

#[test]
fn a_program_that_cannot_be_spawned_is_an_error_not_an_outcome() {
    let s = Scratch::new("x");
    let p = s.path().join("badinterp");
    fs::write(&p, "#!/nonexistent/interp\n").unwrap();
    fs::set_permissions(&p, fs::Permissions::from_mode(0o755))
        .unwrap();
    assert!(matches!(
        run(&p, &[], s.path(), &[], T),
        Err(ExecError::Spawn(_))
    ));
    assert!(
        run(&s.path().join("nope"), &[], s.path(), &[], T).is_err()
    );
}

#[test]
fn resolve_takes_the_first_executable_file_in_search_order() {
    let a = Scratch::new("a");
    let b = Scratch::new("b");
    script(b.path(), "tool", "echo b");
    script(a.path(), "tool", "echo a");
    let got = resolve_program(
        "tool",
        &[a.path().to_path_buf(), b.path().to_path_buf()],
    )
    .unwrap();
    assert_eq!(got, a.path().join("tool"));
}

#[test]
fn resolve_skips_directories_and_non_executables() {
    let a = Scratch::new("a");
    let b = Scratch::new("b");
    fs::create_dir(a.path().join("tool")).unwrap();
    fs::write(b.path().join("tool"), "x").unwrap();
    let c = Scratch::new("c");
    script(c.path(), "tool", "echo c");
    let got = resolve_program(
        "tool",
        &[a.path().into(), b.path().into(), c.path().into()],
    )
    .unwrap();
    assert_eq!(got, c.path().join("tool"));
}

#[test]
fn resolve_fails_when_nothing_matches_and_refuses_odd_names() {
    let a = Scratch::new("a");
    assert!(matches!(
        resolve_program("tool", &[a.path().into()]),
        Err(ExecError::NotFound(_))
    ));
    assert!(
        resolve_program("../tool", &[a.path().into()]).is_err()
    );
    assert!(resolve_program("", &[a.path().into()]).is_err());
}

#[test]
fn resolve_ignores_relative_search_entries() {
    let a = Scratch::new("a");
    script(a.path(), "tool", "echo a");
    assert!(
        resolve_program("tool", &[std::path::PathBuf::from("rel")])
            .is_err()
    );
}
