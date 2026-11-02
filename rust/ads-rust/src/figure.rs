//! Real-axes SVG figures for the demo lessons (ADS-DEMO-001 R-6, D-1 beat 5).
//!
//! Every figure has a title, axis labels with units, ticks, gridlines and a fixed
//! 1280x720 frame that the plot fills. Points come from the demo's own output; no clock,
//! no randomness. Plot types: scatter (with optional fit line) and line.
//!
//! Provable contracts: `padded_range` (the range contains every value and has non-zero
//! width) and `figure_has_axes` (the SVG names both axis labels and draws mesh lines).
use plotters::prelude::*;

/// Frame size in pixels; the SVG-to-PNG step rasterises this SVG with resvg.
pub const SIZE: (u32, u32) = (1280, 720);

/// One drawn series: a legend name, its points and whether it is a line or markers.
pub struct Series<'a> {
    pub name: &'a str,
    pub pts: &'a [(f64, f64)],
    pub line: bool,
}

/// The values' range padded by 5% (at least 0.5 when all values are equal).
pub fn padded_range(vals: impl Iterator<Item = f64>) -> (f64, f64) {
    let (lo, hi) = vals
        .fold((f64::INFINITY, f64::NEG_INFINITY), |a, v| {
            (a.0.min(v), a.1.max(v))
        });
    assert!(lo.is_finite() && hi.is_finite(), "figure needs data");
    let pad = ((hi - lo) * 0.05).max(0.5);
    (lo - pad, hi + pad)
}

/// Draw `series` on shared axes. `labels` is `(title, x label, y label)`, each with units.
pub fn svg(
    labels: (&str, &str, &str),
    series: &[Series],
) -> String {
    let (title, xl, yl) = labels;
    let all = || series.iter().flat_map(|s| s.pts.iter());
    let (x0, x1) = padded_range(all().map(|p| p.0));
    let (y0, y1) = padded_range(all().map(|p| p.1));
    let mut buf = String::new();
    {
        let root = SVGBackend::with_string(&mut buf, SIZE)
            .into_drawing_area();
        root.fill(&WHITE).expect("svg backend writes to a String");
        let mut c = ChartBuilder::on(&root)
            .caption(title, ("sans-serif", 34))
            .margin(24)
            .x_label_area_size(70)
            .y_label_area_size(90)
            .build_cartesian_2d(x0..x1, y0..y1)
            .expect("svg backend writes to a String");
        c.configure_mesh()
            .x_desc(xl)
            .y_desc(yl)
            .axis_desc_style(("sans-serif", 24))
            .label_style(("sans-serif", 20))
            .draw()
            .expect("svg backend writes to a String");
        let palette = [BLUE, RED, GREEN, MAGENTA];
        for (i, s) in series.iter().enumerate() {
            let col = palette[i % palette.len()];
            if s.line {
                c.draw_series(LineSeries::new(
                    s.pts.iter().copied(),
                    col.stroke_width(3),
                ))
                .expect("svg backend writes to a String")
                .label(s.name)
                .legend(move |(x, y)| {
                    PathElement::new(
                        [(x, y), (x + 24, y)],
                        col.stroke_width(3),
                    )
                });
            } else {
                c.draw_series(s.pts.iter().map(|p| {
                    Circle::new(*p, 4, col.mix(0.7).filled())
                }))
                .expect("svg backend writes to a String")
                .label(s.name)
                .legend(move |(x, y)| {
                    Circle::new((x + 12, y), 5, col.filled())
                });
            }
        }
        c.configure_series_labels()
            .background_style(WHITE.mix(0.85))
            .border_style(BLACK)
            .label_font(("sans-serif", 20))
            .draw()
            .expect("svg backend writes to a String");
        root.present().expect("svg backend writes to a String");
    }
    assert!(
        figure_has_axes(&buf, xl, yl),
        "figure_has_axes violated"
    );
    buf
}

/// Least-squares line through `pts` as `(intercept, slope)`.
pub fn fit(pts: &[(f64, f64)]) -> (f64, f64) {
    let n = pts.len() as f64;
    let (mx, my) = (
        pts.iter().map(|p| p.0).sum::<f64>() / n,
        pts.iter().map(|p| p.1).sum::<f64>() / n,
    );
    let sxx: f64 = pts.iter().map(|p| (p.0 - mx).powi(2)).sum();
    let sxy: f64 =
        pts.iter().map(|p| (p.0 - mx) * (p.1 - my)).sum();
    let b = sxy / sxx;
    (my - b * mx, b)
}

/// Scatter of `pts` with its least-squares line, as one figure.
pub fn scatter_fit(
    labels: (&str, &str, &str),
    pts: &[(f64, f64)],
) -> String {
    let (a, b) = fit(pts);
    let (x0, x1) = padded_range(pts.iter().map(|p| p.0));
    let line = [(x0, a + b * x0), (x1, a + b * x1)];
    svg(
        labels,
        &[
            Series {
                name: "observed",
                pts,
                line: false,
            },
            Series {
                name: "least-squares fit",
                pts: &line,
                line: true,
            },
        ],
    )
}

/// The SVG carries each axis label as a whole `<text>` element (never a substring of other
/// markup), the x label upright and the y label rotated, and draws mesh `<line>`s.
pub fn figure_has_axes(svg: &str, xl: &str, yl: &str) -> bool {
    let esc =
        |s: &str| s.replace('&', "&amp;").replace('<', "&lt;");
    // The open tag of the `<text>` element whose whole content is `label`.
    let tag = |label: &str| -> Option<&str> {
        let body = format!(">\n{}\n</text>", esc(label));
        let end = svg.find(&body)?;
        let open = svg[..end].rfind("<text")?;
        Some(&svg[open..end])
    };
    let upright = tag(xl).is_some_and(|t| !t.contains("rotate("));
    let rotated = tag(yl).is_some_and(|t| t.contains("rotate(270"));
    svg.contains("<svg")
        && upright
        && rotated
        && svg.contains("<line")
}

/// Centres `(cx, cy)` of every drawn circle marker, legend keys included.
pub fn circles(svg: &str) -> Vec<(f64, f64)> {
    let attr = |c: &str, name: &str| -> f64 {
        let key = format!("{name}=\"");
        let at =
            c.find(&key).expect("circle attribute") + key.len();
        let val = c[at..].split('"').next().unwrap_or("");
        val.parse().expect("number")
    };
    svg.split("<circle")
        .skip(1)
        .map(|c| (attr(c, "cx"), attr(c, "cy")))
        .collect()
}

/// One scatter series per group on shared axes (e.g. per species or per cluster).
pub fn scatter_groups(
    labels: (&str, &str, &str),
    groups: &[(String, Vec<(f64, f64)>)],
) -> String {
    let series: Vec<Series> = groups
        .iter()
        .map(|(n, p)| Series {
            name: n,
            pts: p,
            line: false,
        })
        .collect();
    svg(labels, &series)
}

/// Split `(group, x, y)` rows into one point list per group, in first-seen order.
pub fn group_points(
    rows: impl Iterator<Item = (String, f64, f64)>,
) -> Vec<(String, Vec<(f64, f64)>)> {
    let mut out: Vec<(String, Vec<(f64, f64)>)> = Vec::new();
    for (g, x, y) in rows {
        match out.iter_mut().find(|e| e.0 == g) {
            Some(e) => e.1.push((x, y)),
            None => out.push((g, vec![(x, y)])),
        }
    }
    out
}

/// Penguin rows as `(species, x column, y column)` from a cleaned frame.
pub fn penguin_rows(
    df: &polars::prelude::DataFrame,
    xc: &str,
    yc: &str,
) -> Vec<(String, f64, f64)> {
    let f = |n: &str| -> Vec<f64> {
        df.column(n)
            .expect("column")
            .f64()
            .expect("f64")
            .into_no_null_iter()
            .collect()
    };
    let sp: Vec<String> = df
        .column("species")
        .expect("species")
        .str()
        .expect("str")
        .into_no_null_iter()
        .map(str::to_string)
        .collect();
    let (x, y) = (f(xc), f(yc));
    sp.into_iter()
        .zip(x)
        .zip(y)
        .map(|((s, a), b)| (s, a, b))
        .collect()
}

/// Two numeric wine columns (any numeric dtype) as `(x, y)` points.
pub fn wine_points(
    df: &polars::prelude::DataFrame,
    xc: &str,
    yc: &str,
) -> Vec<(f64, f64)> {
    use polars::prelude::DataType;
    let f = |n: &str| -> Vec<f64> {
        df.column(n)
            .expect("column")
            .cast(&DataType::Float64)
            .expect("cast")
            .f64()
            .expect("f64")
            .into_no_null_iter()
            .collect()
    };
    f(xc).into_iter().zip(f(yc)).collect()
}

/// Write `svg` as `plot.svg` into `$ADS_OUT` when it is set; no-op otherwise.
pub fn write_if_out(svg: &str) {
    write_to(std::env::var("ADS_OUT").ok().as_deref(), svg);
}

/// Write `svg` as `plot.svg` into `dir` when there is one; no-op otherwise.
pub fn write_to(dir: Option<&str>, svg: &str) {
    if let Some(dir) = dir {
        std::fs::write(format!("{dir}/plot.svg"), svg)
            .expect("plot.svg");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn padded_range_contains_and_widens() {
        let (lo, hi) = padded_range([1.0, 3.0].into_iter());
        assert!(lo < 1.0 && hi > 3.0);
        let (lo, hi) = padded_range([2.0, 2.0].into_iter());
        assert!(hi - lo >= 1.0);
    }

    #[test]
    fn fit_recovers_exact_line() {
        let pts: Vec<_> = (0..5)
            .map(|i| (i as f64, 2.0 + 3.0 * i as f64))
            .collect();
        let (a, b) = fit(&pts);
        assert!((a - 2.0).abs() < 1e-12 && (b - 3.0).abs() < 1e-12);
    }

    #[test]
    fn scatter_fit_has_axes_and_is_deterministic() {
        let pts: Vec<_> =
            (0..8).map(|i| (i as f64, (i * i) as f64)).collect();
        let l = ("t", "x (cm)", "y (g)");
        let (a, b) = (scatter_fit(l, &pts), scatter_fit(l, &pts));
        assert_eq!(a, b);
        assert!(figure_has_axes(&a, "x (cm)", "y (g)"));
        assert!(!figure_has_axes(&a, "missing label", "y (g)"));
    }

    #[test]
    fn axis_labels_match_whole_text_elements_only() {
        let pts = [(0.0, 0.0), (1.0, 2.0), (2.0, 3.0)];
        let svg = scatter_fit(("t", "x", "y"), &pts);
        // "x" is also a substring of the xmlns attribute; only a <text> counts.
        assert!(figure_has_axes(&svg, "x", "y"));
        assert!(!figure_has_axes(&svg, "xml", "y"));
        assert!(!figure_has_axes(&svg, "x", "mlns"));
        // Swapped labels fail: x must be upright, y rotated.
        assert!(!figure_has_axes(&svg, "y", "x"));
        let raw = concat!(
            "<svg><line/><text>\na&amp;b\n</text>",
            "<text transform=\"rotate(270, 1, 2)\">\n&lt;c\n</text>"
        );
        assert!(figure_has_axes(raw, "a&b", "<c"));
        assert!(!figure_has_axes(raw, "<c", "a&b"));
        // A label with no text element at all is refused.
        assert!(!figure_has_axes("<svg><line/>", "a", "b"));
    }

    #[test]
    fn markers_are_one_per_point_plus_a_legend_key_inside_the_frame()
     {
        let pts: Vec<_> =
            (0..8).map(|i| (i as f64, (i * i) as f64)).collect();
        let svg = scatter_fit(("t", "x (u)", "y (u)"), &pts);
        let c = circles(&svg);
        // 8 observations plus the legend key; the fit is a line, not markers.
        assert_eq!(c.len(), pts.len() + 1);
        let (w, h) = (SIZE.0 as f64, SIZE.1 as f64);
        assert!(c.iter().all(|p| p.0 > 0.0 && p.0 < w));
        assert!(c.iter().all(|p| p.1 > 0.0 && p.1 < h));
        let xs: Vec<f64> = c.iter().take(8).map(|p| p.0).collect();
        let ys: Vec<f64> = c.iter().take(8).map(|p| p.1).collect();
        let span = |v: &[f64]| {
            v.iter().cloned().fold(f64::MIN, f64::max)
                - v.iter().cloned().fold(f64::MAX, f64::min)
        };
        // The data fills the panel, not a corner of it.
        assert!(span(&xs) > 0.5 * w);
        assert!(span(&ys) > 0.4 * h);
        let g = scatter_groups(
            ("t", "x (u)", "y (u)"),
            &[
                ("a".to_string(), vec![(0.0, 0.0), (1.0, 1.0)]),
                ("b".to_string(), vec![(2.0, 0.0)]),
            ],
        );
        assert_eq!(circles(&g).len(), 3 + 2);
    }

    #[test]
    fn group_points_keeps_first_seen_order() {
        let g = group_points(
            [("b", 1.0, 2.0), ("a", 3.0, 4.0), ("b", 5.0, 6.0)]
                .into_iter()
                .map(|(s, x, y)| (s.to_string(), x, y)),
        );
        assert_eq!(g.len(), 2);
        assert_eq!((g[0].0.as_str(), g[0].1.len()), ("b", 2));
        let svg = scatter_groups(("t", "x (u)", "y (u)"), &g);
        assert!(figure_has_axes(&svg, "x (u)", "y (u)"));
    }

    #[test]
    fn penguin_rows_pairs_species_with_two_columns() {
        use polars::prelude::*;
        let df = df!(
            "species" => ["Adelie", "Gentoo"],
            "bill_length_mm" => [39.1, 46.5],
            "bill_depth_mm" => [18.7, 13.5],
        )
        .expect("frame");
        let r =
            penguin_rows(&df, "bill_length_mm", "bill_depth_mm");
        assert_eq!(
            r,
            vec![
                ("Adelie".to_string(), 39.1, 18.7),
                ("Gentoo".to_string(), 46.5, 13.5),
            ]
        );
    }

    #[test]
    fn write_to_writes_only_when_there_is_a_directory() {
        let dir = std::env::temp_dir()
            .join(format!("ads-figure-{}", std::process::id()));
        std::fs::create_dir_all(&dir).expect("dir");
        write_to(None, "<svg/>");
        assert!(!dir.join("plot.svg").exists());
        write_to(dir.to_str(), "<svg/>");
        assert_eq!(
            std::fs::read_to_string(dir.join("plot.svg"))
                .expect("plot"),
            "<svg/>"
        );
        std::fs::remove_dir_all(&dir).expect("cleanup");
        write_if_out("<svg/>");
    }

    #[test]
    #[should_panic(expected = "figure needs data")]
    fn empty_series_is_refused() {
        let _ = svg(("t", "x", "y"), &[]);
    }
}
