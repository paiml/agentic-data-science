//! P2: closed-form OLS (ndarray), species model (linfa-linear) and fixed-fold CV.
use ndarray::{Array1, Array2, Axis};
use polars::prelude::DataFrame;
use serde_json::{Value, json};

use linfa::prelude::*;
use linfa_linear::LinearRegression;

/// Species dummy columns after the baseline (Adelie), in golden order.
pub const DUMMIES: [&str; 2] = ["Chinstrap", "Gentoo"];

/// A cleaned frame as plain arrays: flipper length, species, body mass.
pub struct Cols {
    pub flipper: Array1<f64>,
    pub species: Vec<String>,
    pub mass: Array1<f64>,
}

/// Pull the P2 columns out of a cleaned penguins frame (NA policy already applied).
pub fn cols(df: &DataFrame) -> Cols {
    let f64s = |name: &str| -> Array1<f64> {
        let c =
            df.column(name).expect("column").f64().expect("f64");
        c.into_no_null_iter().collect()
    };
    let species = df
        .column("species")
        .expect("species")
        .str()
        .expect("str")
        .into_no_null_iter()
        .map(str::to_string)
        .collect();
    Cols {
        flipper: f64s("flipper_length_mm"),
        species,
        mass: f64s("body_mass_g"),
    }
}

/// Closed-form simple OLS: returns (intercept, slope).
pub fn ols_ndarray(x: &Array1<f64>, y: &Array1<f64>) -> (f64, f64) {
    let (mx, my) =
        (x.mean().unwrap_or(0.0), y.mean().unwrap_or(0.0));
    let sxy = (x - mx).dot(&(y - my));
    let sxx = (x - mx).dot(&(x - mx));
    let slope = sxy / sxx;
    (my - slope * mx, slope)
}

/// Design matrix [flipper, Chinstrap, Gentoo] for the species model.
pub fn design_species(
    flipper: &Array1<f64>,
    species: &[String],
) -> Array2<f64> {
    let mut x = Array2::zeros((flipper.len(), 1 + DUMMIES.len()));
    for (i, s) in species.iter().enumerate() {
        x[[i, 0]] = flipper[i];
        for (j, d) in DUMMIES.iter().enumerate() {
            x[[i, 1 + j]] = f64::from(u8::from(s == d));
        }
    }
    x
}

/// Species model through linfa-linear: returns (intercept, [flipper, Chinstrap, Gentoo]).
pub fn fit_linfa(
    x: &Array2<f64>,
    y: &Array1<f64>,
) -> (f64, Array1<f64>) {
    let m = LinearRegression::new()
        .fit(&Dataset::new(x.clone(), y.clone()))
        .expect("linfa fit");
    (m.intercept(), m.params().clone())
}

/// (rmse, r2) of predictions against observations.
pub fn regression_metrics(
    y: &Array1<f64>,
    pred: &Array1<f64>,
) -> (f64, f64) {
    let sse = (y - pred).mapv(|e| e * e).sum();
    let sst = (y - y.mean().unwrap_or(0.0)).mapv(|e| e * e).sum();
    ((sse / y.len() as f64).sqrt(), 1.0 - sse / sst)
}

/// Fold id per cleaned row, from the committed fixture (`row,fold`).
pub fn read_folds(path: &str) -> Vec<usize> {
    crate::csv_map(path, "folds file", |f| {
        f[1].trim().parse().expect("int")
    })
}

fn predict_species(tr: &Cols, te: &Cols) -> Array1<f64> {
    let (b0, b) = fit_linfa(
        &design_species(&tr.flipper, &tr.species),
        &tr.mass,
    );
    design_species(&te.flipper, &te.species).dot(&b) + b0
}

fn predict_ols(tr: &Cols, te: &Cols) -> Array1<f64> {
    let (b0, b1) = ols_ndarray(&tr.flipper, &tr.mass);
    te.flipper.mapv(|x| b0 + b1 * x)
}

fn subset(c: &Cols, idx: &[usize]) -> Cols {
    Cols {
        flipper: c.flipper.select(Axis(0), idx),
        species: idx
            .iter()
            .map(|&i| c.species[i].clone())
            .collect(),
        mass: c.mass.select(Axis(0), idx),
    }
}

/// Pooled out-of-fold RMSE over the fixed fold assignment.
pub fn cv_rmse(
    c: &Cols,
    folds: &[usize],
    with_species: bool,
) -> f64 {
    let mut pred = Array1::zeros(c.mass.len());
    let mut ids: Vec<usize> = folds.to_vec();
    ids.sort_unstable();
    ids.dedup();
    for k in ids {
        let train: Vec<usize> =
            (0..folds.len()).filter(|&i| folds[i] != k).collect();
        let test: Vec<usize> =
            (0..folds.len()).filter(|&i| folds[i] == k).collect();
        let (tr, te) = (subset(c, &train), subset(c, &test));
        let p = if with_species {
            predict_species(&tr, &te)
        } else {
            predict_ols(&tr, &te)
        };
        for (j, &i) in test.iter().enumerate() {
            pred[i] = p[j];
        }
    }
    regression_metrics(&c.mass, &pred).0
}

/// The golden-file layout for P2.
pub fn p2_json(c: &Cols, folds: &[usize]) -> Value {
    let (b0, b1) = ols_ndarray(&c.flipper, &c.mass);
    let ols_fit = c.flipper.mapv(|x| b0 + b1 * x);
    let x = design_species(&c.flipper, &c.species);
    let (s0, sb) = fit_linfa(&x, &c.mass);
    let sp_fit = x.dot(&sb) + s0;
    let (or, o2) = regression_metrics(&c.mass, &ols_fit);
    let (sr, s2) = regression_metrics(&c.mass, &sp_fit);
    json!({
        "ols": {"intercept": b0, "slope": b1},
        "species_model": {
            "(Intercept)": s0,
            "flipper_length_mm": sb[0],
            "speciesChinstrap": sb[1],
            "speciesGentoo": sb[2],
        },
        "metrics": {"ols": {"rmse": or, "r2": o2}, "species": {"rmse": sr, "r2": s2}},
        "cv_rmse": {"ols": cv_rmse(c, folds, false), "species": cv_rmse(c, folds, true)},
    })
}

/// The contract line in bold green on a terminal, unchanged when piped (the gate reads the plain form).
pub fn verdict(line: &str, tty: bool) -> String {
    if tty {
        format!("\x1b[1;32m{line}\x1b[0m")
    } else {
        line.to_string()
    }
}
