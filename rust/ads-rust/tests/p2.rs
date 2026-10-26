use ads_rust::p1::{na_policy, read_penguins};
use ads_rust::p2::{
    agrees, columns, fit_line, golden, max_diff, Line,
};
use ads_rust::show;

const CSV: &str = "../../datasets/penguins/penguins.csv";
const GOLDEN: &str = "../../datasets/golden/p2.json";

fn clean() -> polars::prelude::DataFrame {
    na_policy(read_penguins(CSV).unwrap()).unwrap()
}

#[test]
fn fit_matches_golden_within_tolerance() {
    let (x, y) = columns(&clean()).unwrap();
    assert_eq!(x.len(), 342);
    let fit = fit_line(&x, &y).unwrap();
    let gold = golden(GOLDEN).unwrap();
    assert!(agrees(&fit, &gold, 1e-2), "{fit:?} vs {gold:?}");
    assert!((fit.intercept + 5780.83).abs() < 1e-2);
    assert!((fit.slope - 49.69).abs() < 1e-2);
}

#[test]
fn agrees_fails_when_a_coefficient_is_off() {
    let a = Line {
        intercept: 1.0,
        slope: 2.0,
    };
    assert!(agrees(&a, &a, 0.0));
    assert!(!agrees(
        &a,
        &Line {
            intercept: 1.5,
            slope: 2.0
        },
        0.1
    ));
    assert!(!agrees(
        &a,
        &Line {
            intercept: 1.0,
            slope: 2.5
        },
        0.1
    ));
}

#[test]
fn fit_rejects_mismatched_lengths() {
    assert!(fit_line(&[1.0, 2.0], &[1.0]).is_err());
}

#[test]
fn columns_reports_a_missing_column() {
    let df = clean().drop("body_mass_g").unwrap();
    assert!(columns(&df).is_err());
}

#[test]
fn golden_reports_bad_files() {
    assert!(golden("no-such-file.json").is_err());
    assert!(golden("../../datasets/penguins/penguins.csv").is_err());
    assert!(golden("../../datasets/golden/p1.json").is_err());
}

#[test]
fn chart_has_title_ticks_and_legend() {
    let df = clean();
    let (x, y) = columns(&df).unwrap();
    let fit = fit_line(&x, &y).unwrap();
    let text = show::render(&df, &fit, 56, 33).unwrap();
    assert_eq!(text.lines().count(), 33);
    for want in
        ["body mass", "7000", "2000", "170", "245", "Gentoo", "fit"]
    {
        assert!(text.contains(want), "missing {want}");
    }
}

#[test]
fn chart_needs_a_species_column() {
    let df = clean().drop("species").unwrap();
    let fit = Line {
        intercept: 0.0,
        slope: 1.0,
    };
    assert!(show::render(&df, &fit, 56, 33).is_err());
}

#[test]
fn tiny_panes_error_instead_of_underflowing() {
    let df = clean();
    let fit = Line {
        intercept: 0.0,
        slope: 1.0,
    };
    assert!(show::render(&df, &fit, 5, 37).is_err());
    assert!(show::render(&df, &fit, 35, 3).is_err());
}

#[test]
fn strip_ansi_removes_colour_codes() {
    let s = "\x1b[1;32mgreen\x1b[0m plain";
    assert_eq!(show::strip_ansi(s), "green plain");
}

#[test]
fn max_diff_is_the_larger_coefficient_gap() {
    let a = Line {
        intercept: 1.0,
        slope: 2.0,
    };
    let b = Line {
        intercept: 1.25,
        slope: 2.5,
    };
    assert!((max_diff(&a, &b) - 0.5).abs() < 1e-12);
    assert!(!agrees(&a, &b, 0.1));
}

#[test]
fn fit_line_on_empty_input_does_not_divide_by_zero() {
    assert!(fit_line(&[], &[]).is_err());
}

#[test]
fn emit_writes_to_a_pane_or_stdout() {
    let f = tmp("pane");
    show::emit("hello", f.to_str()).unwrap();
    assert_eq!(std::fs::read_to_string(&f).unwrap(), "hello\n");
    assert!(show::emit("x", Some("/no/such/dir/pane")).is_err());
    show::emit("to stdout", None).unwrap();
    std::fs::remove_file(&f).unwrap();
}

#[test]
fn emit_truncates_a_longer_old_pane() {
    let f = tmp("trunc");
    std::fs::write(&f, "a much longer old line\n").unwrap();
    show::emit("new", f.to_str()).unwrap();
    assert_eq!(std::fs::read_to_string(&f).unwrap(), "new\n");
    std::fs::remove_file(&f).unwrap();
}

#[test]
fn emit_creates_a_missing_pane_file() {
    let f = tmp("create");
    assert!(!f.exists());
    show::emit("hi", f.to_str()).unwrap();
    assert_eq!(std::fs::read_to_string(&f).unwrap(), "hi\n");
    std::fs::remove_file(&f).unwrap();
}

#[test]
fn output_helpers_print_and_chart_runs() {
    assert_eq!(show::data_path_in("/r", "x"), "/r/datasets/x");
    assert!(show::data_path("golden/p2.json")
        .ends_with("datasets/golden/p2.json"));
    let df = clean();
    let fit = Line {
        intercept: -5780.83,
        slope: 49.69,
    };
    show::rows("rows used", df.height());
    show::line(&fit);
    show::chart(&df, &fit).unwrap();
    show::agreement(1.5e-3, 1e-2);
}

#[test]
fn colour_wraps_only_when_on() {
    assert_eq!(show::colour(false, "\x1b[1m", "ok"), "ok");
    assert_eq!(
        show::colour(true, "\x1b[1m", "ok"),
        "\x1b[1mok\x1b[0m"
    );
}

fn tmp(tag: &str) -> std::path::PathBuf {
    std::env::temp_dir()
        .join(format!("ads-rust-{tag}-{}.txt", std::process::id()))
}

#[test]
fn columns_errors_on_nulls_instead_of_reading_them() {
    let df = polars::df!(
        "flipper_length_mm" => [Some(180.0), None],
        "body_mass_g" => [Some(3000.0), Some(3100.0)]
    )
    .unwrap();
    let err = columns(&df).unwrap_err().to_string();
    assert!(err.contains("flipper_length_mm has 1 nulls"), "{err}");
}

/// Contract CAN_FAIL: raw (uncentred) f32 columns drift the
/// intercept past the tolerance, so the golden check catches it.
#[test]
fn uncentred_f32_fit_is_caught_by_the_golden_check() {
    use aprender::linear_model::LinearRegression;
    use aprender::primitives::{Matrix, Vector};
    use aprender::traits::Estimator;
    let (x, y) = columns(&clean()).unwrap();
    let xs: Vec<f32> = x.iter().map(|v| *v as f32).collect();
    let ys: Vec<f32> = y.iter().map(|v| *v as f32).collect();
    let m = Matrix::from_vec(xs.len(), 1, xs).unwrap();
    let mut model = LinearRegression::new();
    model.fit(&m, &Vector::from_vec(ys)).unwrap();
    let raw = Line {
        intercept: f64::from(model.intercept()),
        slope: f64::from(model.coefficients()[0]),
    };
    let gold = golden(GOLDEN).unwrap();
    assert!(!agrees(&raw, &gold, 1e-2), "{raw:?} vs {gold:?}");
    let good = fit_line(&x, &y).unwrap();
    assert!(agrees(&good, &gold, 1e-2));
}

/// Contract mutation: x and y swapped gives a slope near 0.0153.
#[test]
fn swapped_x_and_y_is_caught_by_the_golden_check() {
    let (x, y) = columns(&clean()).unwrap();
    let swapped = fit_line(&y, &x).unwrap();
    let gold = golden(GOLDEN).unwrap();
    assert!((swapped.slope - 0.0153).abs() < 1e-3, "{swapped:?}");
    assert!(!agrees(&swapped, &gold, 1e-2));
}
