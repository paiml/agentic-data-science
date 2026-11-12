//! The closed command form. Every evasion named in the r2, r3 and r4 review verdicts is a named refusal test.
use demo_emit::parse::{ALLOWED_PROGRAMS, FormKind, parse_cmds};

/// A permissive word list: the byte-level refusal must not depend on the program allow-list.
const PERMISSIVE: &[&str] = &[
    "bat", "cargo", "false", "echo", "eval", "set", "sh", "bash",
    "env", "trap", "exit", "export", "x", "A", "shopt", "alias",
    "fc", "make", "true", "kill", "\\eval",
];

fn kind(input: &str, allow: &[&str]) -> Option<FormKind> {
    parse_cmds(input.as_bytes(), allow).err().map(|e| e.kind)
}

/// Refused under the real list and under the permissive list (the word list is not what refuses it).
fn refused_both(input: &str) {
    assert!(
        kind(input, ALLOWED_PROGRAMS).is_some(),
        "accepted under the real list: {input:?}"
    );
    assert!(
        kind(input, PERMISSIVE).is_some(),
        "accepted under the permissive list: {input:?}"
    );
}

#[test]
fn accepts_the_committed_form() {
    let l = parse_cmds(
        b"bat -r 190:207 src/p3.rs\ncargo run -q --locked --offline --example a-m3-p3-tree\n",
        ALLOWED_PROGRAMS,
    )
    .unwrap();
    assert_eq!(l.len(), 2);
    assert_eq!(l[0].number, 1);
    assert_eq!(l[0].program, "bat");
    assert_eq!(l[0].args, ["-r", "190:207", "src/p3.rs"]);
    assert_eq!(l[1].program, "cargo");
    assert_eq!(l[1].args.len(), 6);
}

#[test]
fn accepts_missing_final_newline_and_tab_separators() {
    let l = parse_cmds(b"cargo\ttest\t--locked", ALLOWED_PROGRAMS)
        .unwrap();
    assert_eq!(l[0].args, ["test", "--locked"]);
}

#[test]
fn the_whole_alphabet_is_accepted_in_arguments() {
    let l = parse_cmds(
        b"cargo a_b.c/d:e=f,g+h@i-j Z9",
        ALLOWED_PROGRAMS,
    )
    .unwrap();
    assert_eq!(l[0].args.len(), 2);
}

#[test]
fn refuses_empty_file() {
    assert_eq!(
        kind("", ALLOWED_PROGRAMS),
        Some(FormKind::EmptyFile)
    );
}

#[test]
fn refuses_empty_line_blank_line_and_whitespace_only_line() {
    assert_eq!(
        kind("cargo test\n\ncargo run\n", ALLOWED_PROGRAMS),
        Some(FormKind::EmptyLine)
    );
    assert_eq!(
        kind("\n", ALLOWED_PROGRAMS),
        Some(FormKind::EmptyLine)
    );
    assert_eq!(
        kind("cargo test\n   \n", ALLOWED_PROGRAMS),
        Some(FormKind::EmptyLine)
    );
}

#[test]
fn the_error_names_the_line() {
    let e = parse_cmds(
        b"cargo test\ncargo run; true\n",
        ALLOWED_PROGRAMS,
    )
    .unwrap_err();
    assert_eq!(e.line, 2);
    assert_eq!(e.kind, FormKind::BadByte(b';'));
}

#[test]
fn refuses_every_shell_metacharacter_in_an_argument() {
    for c in "'\"\\$`;&|<>()*?~#!{}[]%^ \u{b}\u{c}\r\0"
        .chars()
        .filter(|c| *c != ' ')
    {
        let line = format!("cargo test x{c}y");
        refused_both(&line);
    }
}

#[test]
fn refuses_non_ascii_and_nbsp_and_unicode_whitespace() {
    for s in [
        "cargo test é",
        "cargo\u{a0}test",
        "cargo test \u{2003}x",
        "cargo test ＄x",
    ] {
        refused_both(s);
    }
    assert!(matches!(
        kind("cargo test é", ALLOWED_PROGRAMS),
        Some(FormKind::BadByte(_))
    ));
}

#[test]
fn refuses_a_name_value_first_token() {
    assert!(matches!(
        kind("A=1 cargo test", ALLOWED_PROGRAMS),
        Some(FormKind::Assignment(_))
    ));
    assert!(matches!(
        kind("RUSTFLAGS=-Cx cargo test", ALLOWED_PROGRAMS),
        Some(FormKind::Assignment(_))
    ));
}

#[test]
fn refuses_a_program_outside_the_allow_list() {
    for w in [
        "sh", "bash", "env", "eval", "echo", "false", "make", "rm",
        "curl", "set", "exit",
    ] {
        assert!(
            matches!(
                kind(&format!("{w} x"), ALLOWED_PROGRAMS),
                Some(FormKind::ProgramNotAllowed(_))
            ),
            "{w}"
        );
    }
}

#[test]
fn refuses_a_program_word_that_is_a_path_or_has_dots() {
    for w in [
        "./cargo",
        "/usr/bin/cargo",
        "../cargo",
        "ca.rgo",
        "cargo:x",
        "car+go",
        "ca,rgo",
    ] {
        assert!(
            matches!(
                kind(&format!("{w} test"), PERMISSIVE),
                Some(FormKind::BadProgramWord(_))
                    | Some(FormKind::Assignment(_))
            ),
            "{w}"
        );
    }
}

#[test]
fn the_allow_list_is_what_the_committed_rows_use() {
    assert_eq!(ALLOWED_PROGRAMS, ["bat", "cargo"]);
}

// ---- r2 verdict ----

#[test]
fn r2_semicolon_masks_a_failing_middle_command() {
    refused_both("false; echo ok");
}

#[test]
fn r2_subshell_and_brace_group_across_lines() {
    refused_both("(\nfalse\necho ok\n)");
    refused_both("{\nfalse\necho ok;\n}");
}

// ---- r3 verdict ----

#[test]
fn r3_command_substitution_in_an_argument() {
    refused_both("echo $(false)");
    refused_both("export X=$(false)");
}

#[test]
fn r3_multi_command_substitution() {
    refused_both("x=$(false; echo ok)");
}

#[test]
fn r3_and_list_then_semicolon() {
    refused_both("false && echo x; echo ok");
}

#[test]
fn r3_set_plus_e_and_pipefail_off() {
    // No shell runs a row, so `set` is only a program name: refused by the allow-list, never reached.
    for l in ["set +e", "set +o pipefail"] {
        assert!(
            matches!(
                kind(l, ALLOWED_PROGRAMS),
                Some(FormKind::ProgramNotAllowed(_))
            ),
            "{l}"
        );
    }
}

#[test]
fn r3_background_command() {
    refused_both("false &");
}

#[test]
fn r3_pipe_and_and_list() {
    refused_both("false | cat");
    refused_both("false && echo x");
}

// ---- r4 verdict ----

#[test]
fn r4_quoted_command_word_with_ansi_c_quoting() {
    refused_both("\"eval\" $'set +e\\nfalse\\necho ok'");
}

#[test]
fn r4_backslash_escaped_command_word() {
    refused_both("\\eval $'false \\x26\\x26 echo x\\x3b echo ok'");
}

#[test]
fn r4_environment_assignment_prefix_before_a_builtin() {
    refused_both("A=1 eval $'set +e\\nfalse\\necho ok'");
}

#[test]
fn r4_multi_line_quoted_builtins() {
    refused_both("\"set\" +e\n\"eval\" \"false\necho ok\"");
}

#[test]
fn r4_exit_trap_spoofing() {
    refused_both(
        "\"trap\" $'printf \"end 0\\\\n\" > \"$__st\"\\n\"exit\" 0' EXIT\nfalse",
    );
}

#[test]
fn r4_sh_dash_c_subshell() {
    refused_both("sh -c $'false\\necho ok'");
    assert!(matches!(
        kind("sh -c x", ALLOWED_PROGRAMS),
        Some(FormKind::ProgramNotAllowed(_))
    ));
}

#[test]
fn r4_legacy_arithmetic_expansion() {
    refused_both("echo $[1+1]");
}

#[test]
fn r4_read_write_redirection_on_fd_2() {
    refused_both("echo hi 2<>/dev/null");
    refused_both("echo hi &>/dev/null");
}

#[test]
fn r4_env_shopt_alias_fc_eval_as_command_words() {
    for w in ["env", "shopt", "alias", "fc", "eval", "bash", "sh"] {
        assert!(
            matches!(
                kind(&format!("{w} x"), ALLOWED_PROGRAMS),
                Some(FormKind::ProgramNotAllowed(_))
            ),
            "{w}"
        );
    }
}

// ---- the first refusal in a file stops the parse of the whole file ----

#[test]
fn one_bad_line_refuses_the_whole_file() {
    assert!(
        kind("cargo test\ncargo run\nbat x; y\n", ALLOWED_PROGRAMS)
            .is_some()
    );
}
