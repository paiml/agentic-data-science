mod common;
use common::Scratch;
use demo_emit::env::{
    ENV_FILE_KEYS, Host, check_cwd, parse_env_file, session_env,
};
use std::fs;
use std::path::Path;

fn kv(v: &[(String, String)], k: &str) -> Option<String> {
    v.iter().find(|(a, _)| a == k).map(|(_, b)| b.clone())
}

#[test]
fn env_file_parses_and_keeps_the_trailing_space_of_ps1() {
    let v = parse_env_file("# c\n\nTERM=xterm-256color\nPS1=$ \nBAT_THEME=Monokai Extended\nBAT_PAGER=\n").unwrap();
    assert_eq!(kv(&v, "TERM").unwrap(), "xterm-256color");
    assert_eq!(kv(&v, "PS1").unwrap(), "$ ");
    assert_eq!(kv(&v, "BAT_THEME").unwrap(), "Monokai Extended");
    assert_eq!(kv(&v, "BAT_PAGER").unwrap(), "");
}

#[test]
fn the_committed_env_file_parses_and_uses_only_listed_keys() {
    let t = fs::read_to_string(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../term-demos/env"
    ))
    .unwrap();
    let v = parse_env_file(&t).unwrap();
    assert_eq!(v.len(), ENV_FILE_KEYS.len());
    for (k, _) in &v {
        assert!(ENV_FILE_KEYS.contains(&k.as_str()), "{k}");
    }
}

#[test]
fn env_file_refuses_keys_outside_the_list() {
    for k in [
        "LD_PRELOAD",
        "PATH",
        "HOME",
        "LC_ALL",
        "LANG",
        "TZ",
        "CARGO_HOME",
        "RUSTUP_HOME",
        "CARGO_TARGET_DIR",
        "RUSTFLAGS",
        "GIT_CONFIG_GLOBAL",
        "BASH_ENV",
        "ENV",
        "RUSTC_WRAPPER",
    ] {
        assert!(
            parse_env_file(&format!("{k}=x\n")).is_err(),
            "{k}"
        );
    }
}

#[test]
fn env_file_refuses_duplicates_missing_equals_and_odd_bytes() {
    assert!(parse_env_file("TERM=a\nTERM=b\n").is_err());
    assert!(parse_env_file("TERM\n").is_err());
    assert!(parse_env_file("TERM=a\u{1}b\n").is_err());
    assert!(parse_env_file("TERM=é\n").is_err());
    assert!(parse_env_file(" TERM=a\n").is_err());
    assert!(parse_env_file("term=a\n").is_err());
}

fn host(path: &str) -> Host {
    Host {
        path: Some(path.into()),
        home: Some("/h/user".into()),
        cargo_home: None,
        rustup_home: None,
    }
}

#[test]
fn session_env_is_the_file_plus_the_owned_keys_and_nothing_else() {
    let file = vec![("TERM".to_string(), "xterm".to_string())];
    let e = session_env(
        &file,
        &host("/usr/bin:/bin"),
        Path::new("/t/target"),
        Path::new("/r"),
        Path::new("/w/home"),
    )
    .unwrap();
    let mut keys: Vec<&str> =
        e.vars.iter().map(|(k, _)| k.as_str()).collect();
    keys.sort();
    assert_eq!(
        keys,
        [
            "CARGO_HOME",
            "CARGO_TARGET_DIR",
            "GIT_CONFIG_COUNT",
            "GIT_CONFIG_GLOBAL",
            "GIT_CONFIG_KEY_0",
            "GIT_CONFIG_NOSYSTEM",
            "GIT_CONFIG_VALUE_0",
            "HOME",
            "LC_ALL",
            "PATH",
            "RUSTUP_HOME",
            "TERM",
            "TZ"
        ]
    );
    assert_eq!(kv(&e.vars, "HOME").unwrap(), "/w/home");
    assert_eq!(
        kv(&e.vars, "CARGO_HOME").unwrap(),
        "/h/user/.cargo"
    );
    assert_eq!(
        kv(&e.vars, "RUSTUP_HOME").unwrap(),
        "/h/user/.rustup"
    );
    assert_eq!(
        kv(&e.vars, "CARGO_TARGET_DIR").unwrap(),
        "/t/target"
    );
    assert_eq!(kv(&e.vars, "LC_ALL").unwrap(), "C");
    assert_eq!(kv(&e.vars, "TZ").unwrap(), "UTC");
    assert_eq!(kv(&e.vars, "GIT_CONFIG_NOSYSTEM").unwrap(), "1");
    assert_eq!(
        kv(&e.vars, "GIT_CONFIG_GLOBAL").unwrap(),
        "/dev/null"
    );
    assert_eq!(kv(&e.vars, "GIT_CONFIG_VALUE_0").unwrap(), "/r");
}

#[test]
fn session_env_passes_cargo_and_rustup_home_through() {
    let h = Host {
        cargo_home: Some("/c".into()),
        rustup_home: Some("/u".into()),
        ..host("/bin")
    };
    let e = session_env(
        &[],
        &h,
        Path::new("/t"),
        Path::new("/r"),
        Path::new("/w"),
    )
    .unwrap();
    assert_eq!(kv(&e.vars, "CARGO_HOME").unwrap(), "/c");
    assert_eq!(kv(&e.vars, "RUSTUP_HOME").unwrap(), "/u");
}

#[test]
fn path_never_searches_the_working_directory() {
    let e = session_env(
        &[],
        &host(":/usr/bin::rel/bin:.:/bin:"),
        Path::new("/t"),
        Path::new("/r"),
        Path::new("/w"),
    )
    .unwrap();
    assert_eq!(
        e.search,
        [Path::new("/usr/bin"), Path::new("/bin")]
    );
    assert_eq!(kv(&e.vars, "PATH").unwrap(), "/usr/bin:/bin");
}

#[test]
fn session_env_refuses_missing_path_relative_homes_and_no_home() {
    let base = host("/bin");
    let go = |h: &Host| {
        session_env(
            &[],
            h,
            Path::new("/t"),
            Path::new("/r"),
            Path::new("/w"),
        )
    };
    assert!(
        go(&Host {
            path: None,
            ..base.clone()
        })
        .is_err()
    );
    assert!(
        go(&Host {
            path: Some(".:rel".into()),
            ..base.clone()
        })
        .is_err()
    );
    assert!(
        go(&Host {
            cargo_home: Some("rel".into()),
            ..base.clone()
        })
        .is_err()
    );
    assert!(
        go(&Host {
            rustup_home: Some("rel".into()),
            ..base.clone()
        })
        .is_err()
    );
    assert!(
        go(&Host {
            home: None,
            ..base.clone()
        })
        .is_err()
    );
    assert!(
        go(&Host {
            home: None,
            cargo_home: Some("/c".into()),
            rustup_home: Some("/u".into()),
            ..base
        })
        .is_ok()
    );
}

#[test]
fn session_env_refuses_a_relative_target_dir() {
    assert!(
        session_env(
            &[],
            &host("/bin"),
            Path::new("rel/target"),
            Path::new("/r"),
            Path::new("/w")
        )
        .is_err()
    );
}

fn root_with(dirs: &[&str]) -> Scratch {
    let s = Scratch::new("cwd");
    for d in dirs {
        fs::create_dir_all(s.path().join(d)).unwrap();
    }
    s
}

#[test]
fn cwd_accepts_a_relative_directory_inside_the_repo() {
    let s = root_with(&["rust/ads-rust"]);
    let p = check_cwd(s.path(), "rust/ads-rust\n").unwrap();
    assert_eq!(p, s.path().join("rust/ads-rust"));
    assert!(check_cwd(s.path(), "rust/ads-rust").is_ok());
}

#[test]
fn cwd_refuses_absolute_dotdot_and_odd_forms() {
    let s = root_with(&["a/b", "c"]);
    for bad in [
        "", "\n", "/etc", "/", "..", "../x", "a/../c", "./a",
        "a/./b", "a//b", "a/b/", "a b", "a\nb\n", "a/b\r\n", "~",
        "$HOME", "a/\u{e9}", "a/b\n\n", " a/b", "a/*",
    ] {
        assert!(check_cwd(s.path(), bad).is_err(), "{bad:?}");
    }
}

#[test]
fn cwd_refuses_missing_directories_and_plain_files() {
    let s = root_with(&["a"]);
    fs::write(s.path().join("a/file"), "x").unwrap();
    assert!(check_cwd(s.path(), "a/missing").is_err());
    assert!(check_cwd(s.path(), "a/file").is_err());
}

#[test]
fn cwd_refuses_a_symlink_that_leaves_the_repo() {
    let s = root_with(&["a"]);
    let outside = Scratch::new("outside");
    std::os::unix::fs::symlink(
        outside.path(),
        s.path().join("a/escape"),
    )
    .unwrap();
    assert!(check_cwd(s.path(), "a/escape").is_err());
}

#[test]
fn cwd_dot_alone_is_the_checkout_root() {
    let s = root_with(&["a"]);
    for ok in [".", ".\n"] {
        let p = check_cwd(s.path(), ok).unwrap();
        assert_eq!(p, s.path());
    }
    for bad in ["./", "./.", ".\n\n", " .", "..", ".//", "./a"] {
        assert!(check_cwd(s.path(), bad).is_err(), "{bad:?}");
    }
}
