//! Staged terminal demos: one typed command prints the source lines a lesson talks about,
//! then the live result. Plain ASCII, no colour codes.
use std::io::{self, Write};
use std::process::Command;

use crate::p1::{
    max_abs_diff, na_policy, read_penguins, summary_by_species,
};
use crate::p2::{cols, cv_rmse, ols_ndarray, read_folds};
use crate::p3::{p3_json, read_centroids, read_split};

/// Data root: `ADS_ROOT`, default `../..` (as the other examples).
pub fn root() -> String {
    std::env::var("ADS_ROOT").unwrap_or_else(|_| "../..".into())
}

/// Print lines `from..=to` (1-based) of `text`, the embedded source of `label`, under a stage header.
/// A range that is empty or outside the file is refused with `InvalidInput`.
pub fn show(
    out: &mut impl Write,
    label: &str,
    text: &str,
    from: usize,
    to: usize,
) -> io::Result<()> {
    let lines: Vec<&str> = text.lines().collect();
    if from < 1 || from > to || to > lines.len() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!(
                "range {from}-{to} outside {label} ({} lines)",
                lines.len()
            ),
        ));
    }
    writeln!(out, "== source: {label} {from}-{to} ==")?;
    for l in &lines[from - 1..to] {
        writeln!(out, "{l}")?;
    }
    Ok(())
}

/// Print a stage header such as `== run ==`.
pub fn stage(out: &mut impl Write, name: &str) -> io::Result<()> {
    writeln!(out, "== {name} ==")
}

/// Echo `$ program args`, run it in the crate directory with inherited stdout/stderr, return success.
pub fn child(
    out: &mut impl Write,
    program: &str,
    args: &[&str],
) -> io::Result<bool> {
    writeln!(out, "$ {program} {}", args.join(" "))?;
    out.flush()?;
    let st = Command::new(
        std::env::var(program.to_uppercase())
            .unwrap_or_else(|_| program.into()),
    )
    .args(args)
    .current_dir(env!("CARGO_MANIFEST_DIR"))
    .status()?;
    Ok(st.success())
}

/// The OLS stage of `a-m2-p2-ols`: coefficients, then the golden-file contract line.
pub fn ols_result(
    out: &mut impl Write,
    root: &str,
) -> io::Result<()> {
    let df = na_policy(
        read_penguins(&format!(
            "{root}/datasets/penguins/penguins.csv"
        ))
        .expect("load"),
    )
    .expect("policy");
    let c = cols(&df);
    let (b0, b1) = ols_ndarray(&c.flipper, &c.mass);
    writeln!(out, "intercept = {b0:.6}, slope = {b1:.6}")?;
    let g: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(format!(
            "{root}/datasets/golden/p2.json"
        ))
        .expect("golden"),
    )
    .expect("parse");
    let d = (b0 - g["ols"]["intercept"].as_f64().expect("b0"))
        .abs()
        .max((b1 - g["ols"]["slope"].as_f64().expect("b1")).abs());
    assert!(d <= 1e-8, "diff {d}");
    writeln!(
        out,
        "contract: ads-rust-p2-v1 ols max |diff| = {d:e} OK"
    )
}

/// The contract line of `a-m1-p1`, computed from the loaded and kept row counts.
pub fn p1_contract(
    out: &mut impl Write,
    root: &str,
) -> io::Result<()> {
    let raw = read_penguins(&format!(
        "{root}/datasets/penguins/penguins.csv"
    ))
    .expect("load");
    let kept = na_policy(raw.clone()).expect("policy");
    assert_eq!((raw.height(), kept.height()), (344, 342));
    writeln!(
        out,
        "contract: ads-rust-p1-v1 rows {} -> {} OK",
        raw.height(),
        kept.height()
    )
}

/// Print several line ranges of `text` under one header `== source: label 23,44-51 ==`.
/// Any empty or out-of-file range is refused with `InvalidInput` before anything is printed.
pub fn show_ranges(
    out: &mut impl Write,
    label: &str,
    text: &str,
    ranges: &[(usize, usize)],
) -> io::Result<()> {
    let lines: Vec<&str> = text.lines().collect();
    for &(from, to) in ranges {
        if from < 1 || from > to || to > lines.len() {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                format!(
                    "range {from}-{to} outside {label} ({} lines)",
                    lines.len()
                ),
            ));
        }
    }
    let spans: Vec<String> = ranges
        .iter()
        .map(|&(f, t)| {
            if f == t {
                f.to_string()
            } else {
                format!("{f}-{t}")
            }
        })
        .collect();
    writeln!(out, "== source: {label} {} ==", spans.join(","))?;
    for &(from, to) in ranges {
        for l in &lines[from - 1..to] {
            writeln!(out, "{l}")?;
        }
    }
    Ok(())
}

/// The CV stage of `a-m2-p2-cv`: both pooled RMSEs, then the golden-file contract line.
pub fn cv_result(
    out: &mut impl Write,
    root: &str,
) -> io::Result<()> {
    let df = na_policy(
        read_penguins(&format!(
            "{root}/datasets/penguins/penguins.csv"
        ))
        .expect("load"),
    )
    .expect("policy");
    let folds =
        read_folds(&format!("{root}/datasets/fixtures/folds.csv"));
    let c = cols(&df);
    let (ols, sp) =
        (cv_rmse(&c, &folds, false), cv_rmse(&c, &folds, true));
    let head = format!(
        "cv_rmse (ols):     {ols:.6}\ncv_rmse (species): {sp:.6}"
    );
    writeln!(out, "{head}")?;
    let g: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(format!(
            "{root}/datasets/golden/p2.json"
        ))
        .expect("golden"),
    )
    .expect("parse");
    let d = (ols - g["cv_rmse"]["ols"].as_f64().expect("ols"))
        .abs()
        .max(
            (sp - g["cv_rmse"]["species"].as_f64().expect("sp"))
                .abs(),
        );
    assert!(d <= 1e-6, "diff {d}");
    writeln!(
        out,
        "contract: ads-rust-p2-v1 cv max |diff| = {d:e} OK"
    )
}

/// The tree stage of `a-m3-p3-tree`: accuracy and confusion matrix, then the golden-file contract line.
pub fn p3_result(
    out: &mut impl Write,
    root: &str,
) -> io::Result<()> {
    let df = na_policy(
        read_penguins(&format!(
            "{root}/datasets/penguins/penguins.csv"
        ))
        .expect("load"),
    )
    .expect("policy");
    let split =
        read_split(&format!("{root}/datasets/fixtures/split.csv"));
    let cen = read_centroids(&format!(
        "{root}/datasets/fixtures/centroids.csv"
    ));
    let got = p3_json(&df, &split, &cen);
    let head = format!(
        "accuracy:  {}\nconfusion: {}",
        got["accuracy"], got["confusion"]
    );
    writeln!(out, "{head}")?;
    let g: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(format!(
            "{root}/datasets/golden/p3.json"
        ))
        .expect("golden"),
    )
    .expect("parse");
    assert_eq!(got["confusion"], g["confusion"]);
    writeln!(
        out,
        "contract: ads-rust-p3-v1 confusion equals golden OK"
    )
}

/// Process exit code of a demo: 0 on success, 1 when a child failed, 2 on an error.
pub fn code(r: io::Result<bool>) -> i32 {
    match r {
        Ok(true) => 0,
        Ok(false) => 1,
        Err(e) => {
            eprintln!("staged demo failed: {e}");
            2
        }
    }
}

/// Flush `out`, then block until one line (or end of input) arrives on `input`.
pub fn pause(
    out: &mut impl Write,
    input: &mut impl io::BufRead,
) -> io::Result<()> {
    out.flush()?;
    input.read_line(&mut String::new()).map(|_| ())
}

/// The result stage of `a-m1-p1`: rows loaded and kept, then the contract line.
pub fn p1_counts(
    out: &mut impl Write,
    root: &str,
) -> io::Result<()> {
    let raw = read_penguins(&format!(
        "{root}/datasets/penguins/penguins.csv"
    ))
    .expect("load");
    let kept = na_policy(raw.clone()).expect("policy");
    let head = format!(
        "rows loaded: {}\nrows kept:   {}",
        raw.height(),
        kept.height()
    );
    writeln!(out, "{head}")?;
    p1_contract(out, root)
}

/// The result stage of `a-m1-p1-profile`: the largest gap from the golden file, as its contract line.
pub fn p1_profile(
    out: &mut impl Write,
    root: &str,
) -> io::Result<()> {
    let df = na_policy(
        read_penguins(&format!(
            "{root}/datasets/penguins/penguins.csv"
        ))
        .expect("load"),
    )
    .expect("policy");
    let s = summary_by_species(df).expect("summary");
    let g: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(format!(
            "{root}/datasets/golden/p1.json"
        ))
        .expect("golden"),
    )
    .expect("parse");
    let d = max_abs_diff(&s, &g);
    assert!(d <= 1e-9, "diff {d}");
    let line =
        format!("contract: ads-rust-p1-v1 max |diff| = {d:e} OK");
    writeln!(out, "{line}")
}
