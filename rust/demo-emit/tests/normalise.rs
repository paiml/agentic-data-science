use demo_emit::normalise::{
    Roots, find_leak, is_cargo_test, normalise, strip_terminal,
    test_facts,
};

fn roots() -> Roots {
    Roots {
        target: vec!["/w/runner/target".into()],
        root: vec![
            "/w/checkout".into(),
            "/mnt/real/checkout".into(),
        ],
        host: vec!["/root".into(), "/usr/local/cargo".into()],
    }
}

#[test]
fn ansi_and_carriage_returns_are_stripped() {
    assert_eq!(
        strip_terminal(
            "\u{1b}[1;32mok\u{1b}[0m\r\nx\u{1b}]0;title\u{7}y\r\n"
        ),
        "ok\nxy\n"
    );
}

#[test]
fn the_root_and_target_become_tokens_longest_first() {
    let r = Roots {
        target: vec!["/w/checkout/rust/ads-rust/target".into()],
        root: vec!["/w/checkout".into()],
        host: vec![],
    };
    assert_eq!(
        normalise(
            "see /w/checkout/rust/ads-rust/target/debug/x and /w/checkout/src/p1.rs\n",
            &r
        ),
        "see target/debug/x and ./src/p1.rs\n"
    );
}

#[test]
fn logical_and_physical_spellings_both_normalise() {
    let n = normalise(
        "a /w/checkout/x b /mnt/real/checkout/y c /w/runner/target/z\n",
        &roots(),
    );
    assert_eq!(n, "a ./x b ./y c target/z\n");
}

#[test]
fn a_root_is_replaced_only_at_a_path_boundary() {
    let n = normalise(
        "/w/checkout2/x and /w/checkoutx and /w/checkout/y\n",
        &roots(),
    );
    assert!(n.contains("/w/checkout2/x"));
    assert!(n.contains("/w/checkoutx"));
    assert!(n.contains(" ./y"), "{n}");
}

#[test]
fn r2_llvm_cov_target_and_hyphenated_binaries_pin_the_hash() {
    let t = "     Running unittests src/lib.rs (/w/runner/target/llvm-cov-target/debug/deps/ads_rust-0123456789abcdef)\n\
             Running unittests examples/a-m1-p1/main.rs (/w/runner/target/llvm-cov-target/debug/examples/a_m1_p1-fedcba9876543210)\n\
             Running tests/p1.rs (/w/runner/target/debug/deps/a-m1-p1-profile-00ff00ff00ff00ff)\n";
    let n = normalise(t, &roots());
    assert!(n.contains("(target/llvm-cov-target/debug/deps/ads_rust-0000000000000000)"), "{n}");
    assert!(n.contains("(target/llvm-cov-target/debug/examples/a_m1_p1-0000000000000000)"), "{n}");
    assert!(
        n.contains(
            "(target/debug/deps/a-m1-p1-profile-0000000000000000)"
        ),
        "{n}"
    );
    assert!(find_leak(&n, &roots()).is_none());
}

#[test]
fn r2_a_checkout_without_a_target_override_normalises_the_same_way()
{
    let r = Roots {
        target: vec!["/w/checkout/rust/ads-rust/target".into()],
        root: vec!["/w/checkout".into()],
        host: vec![],
    };
    let n = normalise(
        "(/w/checkout/rust/ads-rust/target/llvm-cov-target/debug/deps/p1-0123456789abcdef)\n",
        &r,
    );
    assert_eq!(
        n,
        "(target/llvm-cov-target/debug/deps/p1-0000000000000000)\n"
    );
}

#[test]
fn r3_a_trailing_slash_on_the_target_dir_does_not_break_the_hash_rule()
 {
    // The caller strips the slash; a spelling that still carries one must not eat the separator.
    let r = Roots {
        target: vec!["/w/runner/target/".into()],
        root: vec![],
        host: vec![],
    };
    let n = normalise(
        "/w/runner/target/debug/deps/p1-0123456789abcdef\n",
        &r,
    );
    assert_eq!(n, "target/debug/deps/p1-0000000000000000\n");
}

#[test]
fn a_hash_outside_a_target_path_is_not_rewritten_and_is_then_a_leak()
 {
    let n = normalise("id deadbeefdeadbeef\n", &roots());
    assert_eq!(n, "id deadbeefdeadbeef\n");
    assert!(find_leak(&n, &roots()).is_some());
}

#[test]
fn cargo_progress_lines_are_dropped_and_other_lines_kept() {
    let t = "   Compiling foo v0.1.0\n    Checking bar v0.2.0\n       Fresh baz v1.0.0\n Downloading crates ...\n  Downloaded x v1\n\
             warning: unused\n    Finished `test` profile in 1.2s\n     Running tests/p1.rs\n   Doc-tests ads_rust\n  Compiling short\nCompiling nopad\n";
    let n = normalise(t, &Roots::default());
    assert_eq!(
        n,
        "warning: unused\n    Finished `test` profile in 0.00s\n     Running tests/p1.rs\n   Doc-tests ads_rust\n  Compiling short\nCompiling nopad\n"
    );
}

#[test]
fn timings_and_measured_lines_are_tokenised() {
    let t = "test result: ok. 8 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 12.34s\n\
             Finished in 3s\n   polars: 12.345678 ms\n btreemap: 0.5 ms\nnot polars: 1.0 ms\n";
    let n = normalise(t, &Roots::default());
    assert!(n.contains("finished in 0.00s"), "{n}");
    assert!(n.contains("Finished in 0.00s"), "{n}");
    assert!(n.contains("   polars: 0.000000 ms\n"), "{n}");
    assert!(n.contains(" btreemap: 0.000000 ms\n"), "{n}");
    assert!(n.contains("not polars: 1.0 ms"), "{n}");
}

#[test]
fn a_commit_hash_after_commit_equals_is_tokenised() {
    let n = normalise(
        &format!("commit={}\n", "ab12".repeat(10)),
        &Roots::default(),
    );
    assert_eq!(n, format!("commit={}\n", "0".repeat(40)));
}

#[test]
fn normalisation_is_idempotent() {
    let t = "   Compiling a v1\n/w/checkout/x (/w/runner/target/debug/deps/p1-0123456789abcdef) in 1.00s\n";
    let once = normalise(t, &roots());
    assert_eq!(normalise(&once, &roots()), once);
}

// ---- leak refusal ----

#[test]
fn leak_refuses_host_prefixes_and_the_literal_host_paths() {
    for t in [
        "at /home/u/x",
        "at /tmp/x",
        "at /root/.cargo",
        "at /Users/me",
        "at /runner/work",
        "at /github/workspace",
        "at /__w/r/r",
        "at /var/folders/x",
        "at /private/x",
        "at /mnt/disk",
        "at /usr/local/cargo/bin/x",
        "(/tmp)",
    ] {
        let l = find_leak(t, &roots())
            .unwrap_or_else(|| panic!("no leak in {t}"));
        assert_eq!(l.line, 1);
    }
}

#[test]
fn leak_names_the_line() {
    let l =
        find_leak("fine\nfine\nat /home/x\n", &roots()).unwrap();
    assert_eq!(l.line, 3);
}

#[test]
fn leak_does_not_fire_on_relative_paths_and_urls_of_normal_text() {
    assert!(
        find_leak(
            "src/p1.rs:3 and target/debug and ./x and a/home/b",
            &roots()
        )
        .is_none()
    );
}

#[test]
fn leak_refuses_a_volatile_hex_run_but_not_exact_zero_tokens() {
    assert!(find_leak("0123456789abcdef", &roots()).is_some());
    assert!(find_leak("DEADBEEFDEADBEEF", &roots()).is_some());
    assert!(
        find_leak(&format!("x {} y", "a".repeat(40)), &roots())
            .is_some()
    );
    assert!(find_leak(&"0".repeat(16), &roots()).is_none());
    assert!(find_leak(&"0".repeat(40), &roots()).is_none());
    assert!(find_leak(&"0".repeat(17), &roots()).is_some());
    assert!(find_leak(&"0".repeat(15), &roots()).is_none());
}

#[test]
fn leak_allows_a_whole_decimal_literal() {
    for t in [
        "x -5780.826463700001 y",
        "1.0123456789012345",
        "0.12345678901234567890",
        "+3.14159265358979323846e-10",
        "394.31296",
    ] {
        assert!(find_leak(t, &roots()).is_none(), "{t}");
    }
}

#[test]
fn r3_leak_does_not_exempt_a_hex_token_after_digit_dot() {
    for t in [
        "echo p1.0123456789abcdef",
        concat!("v1.", "0123456789abcdef", "0123456789abcdef", "01234567"),
        "0.deadbeefcafebabe",
        "0.0123456789abcdef",
    ] {
        assert!(find_leak(t, &roots()).is_some(), "{t}");
    }
}

#[test]
fn r4_leak_does_not_exempt_a_run_glued_to_a_longer_token() {
    for t in [
        "build/out-0123456789012345.0-x86_64",
        "pkg-1.0123456789012345-rc1",
        "v1+0.0123456789012345",
        "0.01234567e89012345",
        "sha=0.1e0123456789012345",
        "rev:0123456789012345.1",
        "1.5e3x0123456789012345",
    ] {
        assert!(find_leak(t, &roots()).is_some(), "{t}");
    }
}

#[test]
fn r4_leak_scans_hex_case_insensitively() {
    assert!(find_leak("0123456789ABCDEF", &roots()).is_some());
    assert!(find_leak("0123456789aBcDeF", &roots()).is_some());
}

// ---- test facts ----

fn res(p: u64, f: u64, i: u64) -> String {
    format!(
        "test result: ok. {p} passed; {f} failed; {i} ignored; 0 measured; 0 filtered out; finished in 0.00s\n"
    )
}

#[test]
fn test_facts_sum_every_result_line() {
    let t = format!("{}{}", res(8, 0, 0), res(1, 0, 0));
    assert_eq!(test_facts(&t).unwrap().passed, 9);
}

#[test]
fn test_facts_refuse_no_line_failed_ignored_and_zero_passed() {
    assert!(test_facts("running 0 tests\n").is_err());
    assert!(test_facts(&res(3, 1, 0)).is_err());
    assert!(test_facts(&res(3, 0, 1)).is_err());
    assert!(test_facts(&res(0, 0, 0)).is_err());
    assert!(
        test_facts(&format!("{}{}", res(3, 0, 0), res(0, 0, 2)))
            .is_err()
    );
}

#[test]
fn a_result_line_must_start_the_line() {
    assert!(test_facts(&format!("echo {}", res(3, 0, 0))).is_err());
}

#[test]
fn is_cargo_test_reads_the_subcommand() {
    let a = |v: &[&str]| {
        v.iter().map(|s| s.to_string()).collect::<Vec<_>>()
    };
    assert!(is_cargo_test("cargo", &a(&["test", "--locked"])));
    assert!(is_cargo_test("cargo", &a(&["-q", "test"])));
    assert!(is_cargo_test("cargo", &a(&["+nightly", "test"])));
    assert!(!is_cargo_test("cargo", &a(&["run", "--", "test"])));
    assert!(!is_cargo_test(
        "cargo",
        &a(&["run", "--example", "test"])
    ));
    assert!(!is_cargo_test("bat", &a(&["test"])));
    assert!(!is_cargo_test("cargo", &a(&[])));
}
