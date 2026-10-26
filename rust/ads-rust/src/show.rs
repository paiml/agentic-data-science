//! Terminal output for the demos: styled lines and the species chart.
//!
//! The chart is drawn with aprender's own visualisation crate and
//! printed as half-block cells; the tick labels are plain text.
use crate::p2::Line;
use polars::prelude::*;
use std::io::{IsTerminal, Write};
use trueno_viz::color::Rgba;
use trueno_viz::grammar::{
    Aes, Coord, DataFrame as Frame, GGPlot, Geom, Layer, Theme,
};
use trueno_viz::output::{TerminalEncoder, TerminalMode};

/// Axis limits: five equal grid steps with round tick labels.
const X_LIM: (f32, f32) = (170.0, 245.0);
const Y_LIM: (f32, f32) = (2000.0, 7000.0);
/// Plot margin in pixels (one pixel is one terminal column).
const MARGIN: u32 = 1;
const GREEN: &str = "\x1b[1;32m";
const BLUE: &str = "\x1b[1;36m";
const END: &str = "\x1b[0m";
/// Species and their colours (Adelie, Chinstrap, Gentoo).
const SPECIES: [(&str, (u8, u8, u8)); 3] = [
    ("Adelie", (255, 140, 0)),
    ("Chinstrap", (190, 80, 255)),
    ("Gentoo", (0, 200, 200)),
];
const FIT: (u8, u8, u8) = (255, 60, 60);

/// The `i`-th of five equal steps across an axis range.
fn lim_at(lim: (f32, f32), i: u32) -> f32 {
    lim.0 + (lim.1 - lim.0) * i as f32 / 5.0
}

/// Path of a file under the data directory of the course at `root`.
pub fn data_path_in(root: &str, rel: &str) -> String {
    format!("{root}/datasets/{rel}")
}

/// Path of a file under the course data directory (`ADS_ROOT`).
pub fn data_path(rel: &str) -> String {
    let root = std::env::var("ADS_ROOT")
        .unwrap_or_else(|_| "../..".into());
    data_path_in(&root, rel)
}

fn paint(code: &str, text: &str) -> String {
    colour(std::io::stdout().is_terminal(), code, text)
}

/// Wrap `text` in an ANSI colour when `on`.
pub fn colour(on: bool, code: &str, text: &str) -> String {
    match on {
        true => format!("{code}{text}{END}"),
        false => text.to_string(),
    }
}

/// Print a labelled row count.
pub fn rows(label: &str, n: usize) {
    println!("{label}: {n}");
}

/// Print the fitted coefficients.
pub fn line(l: &Line) {
    println!(
        "intercept = {:.2}, slope = {:.2}",
        l.intercept, l.slope
    );
}

/// Print the measured largest coefficient difference and the tolerance.
pub fn agreement(diff: f64, atol: f64) {
    println!(
        "{}",
        paint(
            GREEN,
            &format!("max |beta - golden| = {diff:.2e} (atol {atol:.0e})")
        )
    );
}

fn rgba(c: (u8, u8, u8)) -> Rgba {
    Rgba::new(c.0, c.1, c.2, 255)
}

fn species_frame(
    df: &DataFrame,
    name: &str,
) -> PolarsResult<Frame> {
    let mask = col("species").eq(lit(name));
    let sub = df.clone().lazy().filter(mask).collect()?;
    let (x, y) = crate::p2::columns(&sub)?;
    let f = |v: Vec<f64>| {
        v.into_iter().map(|a| a as f32).collect::<Vec<_>>()
    };
    Ok(Frame::from_xy(&f(x), &f(y)))
}

/// Plot the penguins by species with the fitted line, as terminal text.
pub fn render(
    df: &DataFrame,
    l: &Line,
    cols: u32,
    rows: u32,
) -> Result<String, Box<dyn std::error::Error>> {
    let w = cols.checked_sub(6).filter(|w| *w > 2 * MARGIN);
    let h = rows.checked_sub(4).filter(|h| *h > 0).map(|h| h * 2);
    let (Some(w), Some(h)) = (w, h) else {
        return Err("chart pane too small".into());
    };
    let mut plot = GGPlot::new()
        .data_xy(&[X_LIM.0], &[Y_LIM.0])
        .aes(Aes::new().x("x").y("y"))
        .coord(
            Coord::cartesian()
                .xlim(X_LIM.0.into(), X_LIM.1.into())
                .ylim(Y_LIM.0.into(), Y_LIM.1.into()),
        )
        .theme(Theme::dark().margin(MARGIN))
        .dimensions(w, h);
    for (name, c) in SPECIES {
        let layer =
            Layer::new(Geom::point().aes(
                Aes::new().color_value(rgba(c)).size_value(1.0),
            ));
        plot = plot.layer(layer.data(species_frame(df, name)?));
    }
    let (xs, _) = crate::p2::columns(df)?;
    let lo = xs.iter().copied().fold(f64::INFINITY, f64::min);
    let hi = xs.iter().copied().fold(f64::NEG_INFINITY, f64::max);
    let (x0, x1) = (lo as f32, hi as f32);
    let at = |x: f32| (l.intercept + l.slope * f64::from(x)) as f32;
    let fit = Frame::from_xy(&[x0, x1], &[at(x0), at(x1)]);
    let fit = Layer::new(
        Geom::line().aes(Aes::new().color_value(rgba(FIT))),
    )
    .data(fit);
    let fb = plot.layer(fit).build()?.to_framebuffer()?;
    let body = TerminalEncoder::new()
        .mode(TerminalMode::UnicodeHalfBlock)
        .width(w)
        .render(&fb);
    Ok(decorate(&body, cols, h / 2))
}

/// Add the title, y ticks, x ticks and legend around the chart rows.
fn decorate(body: &str, cols: u32, rows: u32) -> String {
    let mut out = format!(
        "{}\n",
        paint(BLUE, "body mass (g) vs flipper (mm)")
    );
    let plot_h = (rows * 2).saturating_sub(2 * MARGIN);
    let tick_row = |i: u32| (MARGIN + plot_h - plot_h * i / 5) / 2;
    let ticks: Vec<(u32, String)> = (0..=5)
        .map(|i| {
            (
                tick_row(i).min(rows - 1),
                format!("{:>5.0}", lim_at(Y_LIM, i)),
            )
        })
        .collect();
    for (r, line) in body.lines().enumerate() {
        let label = ticks
            .iter()
            .find(|t| t.0 as usize == r)
            .map_or("     ".to_string(), |t| t.1.clone());
        out.push_str(&format!("{label} {line}\n"));
    }
    let mut axis = vec![b' '; cols as usize];
    for i in 0..=5_u32 {
        let c = (6 + MARGIN + (cols - 6 - 2 * MARGIN) * i / 5)
            .saturating_sub(1)
            .min(cols - 3) as usize;
        axis[c..c + 3].copy_from_slice(
            format!("{:.0}", lim_at(X_LIM, i)).as_bytes(),
        );
    }
    out.push_str(&format!("{}\n", String::from_utf8_lossy(&axis)));
    let key = |(name, c): &(&str, (u8, u8, u8))| {
        format!("\x1b[38;2;{};{};{}m■\x1b[0m {name}", c.0, c.1, c.2)
    };
    let legend: Vec<String> = SPECIES.iter().map(key).collect();
    out.push_str(&format!(
        "{}\n{}  \x1b[38;2;{};{};{}m━\x1b[0m fit",
        legend[..2].join("  "),
        legend[2],
        FIT.0,
        FIT.1,
        FIT.2
    ));
    out
}

/// Send text to the side pane named by `ADS_PLOT_PANE`, else to stdout.
pub fn emit(text: &str, pane: Option<&str>) -> std::io::Result<()> {
    match pane {
        Some(p) => writeln!(
            std::fs::OpenOptions::new()
                .write(true)
                .create(true)
                .truncate(true)
                .open(p)?,
            "{text}"
        ),
        None => writeln!(std::io::stdout(), "{text}"),
    }
}

/// Remove ANSI escape sequences (colour codes) from `text`.
pub fn strip_ansi(text: &str) -> String {
    let mut out = String::new();
    let mut it = text.chars();
    while let Some(c) = it.next() {
        match c {
            '\x1b' => {
                for e in it.by_ref() {
                    if e.is_ascii_alphabetic() {
                        break;
                    }
                }
            }
            _ => out.push(c),
        }
    }
    out
}

/// Draw the species chart with the fitted line.
pub fn chart(
    df: &DataFrame,
    l: &Line,
) -> Result<(), Box<dyn std::error::Error>> {
    let text = render(df, l, 35, 37)?;
    let pane = std::env::var("ADS_PLOT_PANE").ok();
    let on = pane.is_some() || std::io::stdout().is_terminal();
    let text = if on { text } else { strip_ansi(&text) };
    Ok(emit(&text, pane.as_deref())?)
}
