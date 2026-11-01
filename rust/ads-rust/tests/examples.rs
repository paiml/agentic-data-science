use std::process::Command;

/// Runs a built example and returns (success, last stdout line).
fn run_example(name: &str) -> (bool, String) {
    let out = Command::new(env!("CARGO"))
        .args(["run", "-q", "--locked", "--example", name])
        .env("ADS_ROOT", "../..")
        .output()
        .unwrap();
    let stdout = String::from_utf8(out.stdout).unwrap();
    let last = stdout.lines().last().unwrap_or("").to_string();
    (out.status.success(), last)
}

fn assert_verdict(name: &str) {
    let (ok, last) = run_example(name);
    assert!(ok, "{name} exited non-zero");
    assert!(
        last.starts_with("contract: ") && last.ends_with(" OK"),
        "{name} last line is not an OK verdict: {last}"
    );
}

#[test]
fn a_m1_p1_last_line_is_the_ok_verdict() {
    assert_verdict("a-m1-p1");
}

#[test]
fn a_m1_p1_profile_last_line_is_the_ok_verdict() {
    assert_verdict("a-m1-p1-profile");
}

#[test]
fn anscombe_last_line_is_the_ok_verdict() {
    assert_verdict("anscombe");
}

#[test]
fn anscombe_writes_stdout_and_plot_when_asked() {
    let d = tempfile::tempdir().unwrap();
    let out = Command::new(env!("CARGO"))
        .args(["run", "-q", "--locked", "--example", "anscombe"])
        .env("ADS_ROOT", "../..")
        .env("ADS_OUT", d.path())
        .output()
        .unwrap();
    assert!(out.status.success());
    let text = std::fs::read_to_string(d.path().join("stdout.txt"))
        .unwrap();
    assert_eq!(text.lines().count(), 4);
    assert!(
        std::fs::read_to_string(d.path().join("plot.svg"))
            .unwrap()
            .starts_with("<svg")
    );
}

#[test]
fn hero_draws_every_landed_language_and_ends_ok() {
    let d = tempfile::tempdir().unwrap();
    std::fs::create_dir(d.path().join("rust")).unwrap();
    let plot = ads_rust::anscombe::plot_svg(
        &ads_rust::anscombe::parse(
            &std::fs::read_to_string(
                "../../data/anscombe/anscombe.csv",
            )
            .unwrap(),
        )
        .unwrap(),
    );
    std::fs::write(d.path().join("rust/plot.svg"), plot).unwrap();
    std::fs::write(d.path().join("landed"), "rust\n").unwrap();
    let out = Command::new(env!("CARGO"))
        .args(["run", "-q", "--locked", "--example", "hero", "--"])
        .arg(d.path())
        .arg(d.path().join("landed"))
        .arg(d.path().join("hero.svg"))
        .output()
        .unwrap();
    assert!(out.status.success());
    let last = String::from_utf8(out.stdout).unwrap();
    assert!(last.trim_end().ends_with(" OK"), "{last}");
    assert!(
        std::fs::read_to_string(d.path().join("hero.svg"))
            .unwrap()
            .contains(">rust<")
    );
}
