//! Real-axes SVG figures for the demo lessons (ADS-DEMO-001 R-6, D-1 beat 5).
//!
//! Every figure has a title, axis labels with units, ticks, gridlines and a fixed
//! 1280x720 frame that the plot fills. Points come from the demo's own output; no clock,
//! no randomness. Plot types: scatter (with optional fit line) and line.
//!
//! Provable contracts: `padded_range` (the range contains every value and has non-zero
//! width) and `figure_has_axes` (the SVG names both axis labels and draws mesh lines).
use plotters::prelude::*;

/// Frame size in pixels; rmedia rasterises this SVG with resvg.
pub const SIZE: (u32, u32) = (1280, 720);

/// One drawn series: a legend name, its points and whether it is a line or markers.
pub struct Series<'a> {
    pub name: &'a str,
    pub pts: &'a [(f64, f64)],
    pub line: bool,
}

/// The values' range padded by 5% (at least 0.5 when all values are equal).
pub fn padded_range(vals: impl Iterator<Item = f64>) -> (f64, f64) {
    let (lo, hi) = vals.fold((f64::INFINITY, f64::NEG_INFINITY), |a, v| {
        (a.0.min(v), a.1.max(v))
    });
    assert!(lo.is_finite() && hi.is_finite(), "figure needs data");
    let pad = ((hi - lo) * 0.05).max(0.5);
    (lo - pad, hi + pad)
}

/// Draw `series` on shared axes. `labels` is `(title, x label, y label)`, each with units.
pub fn svg(labels: (&str, &str, &str), series: &[Series]) -> String {
    let (title, xl, yl) = labels;
    let all = || series.iter().flat_map(|s| s.pts.iter());
    let (x0, x1) = padded_range(all().map(|p| p.0));
    let (y0, y1) = padded_range(all().map(|p| p.1));
    let mut buf = String::new();
    {
        let root = SVGBackend::with_string(&mut buf, SIZE).into_drawing_area();
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
                c.draw_series(LineSeries::new(s.pts.iter().copied(), col.stroke_width(3)))
                    .expect("svg backend writes to a String")
                    .label(s.name)
                    .legend(move |(x, y)| {
                        PathElement::new([(x, y), (x + 24, y)], col.stroke_width(3))
                    });
            } else {
                c.draw_series(s.pts.iter().map(|p| Circle::new(*p, 4, col.mix(0.7).filled())))
                    .expect("svg backend writes to a String")
                    .label(s.name)
                    .legend(move |(x, y)| Circle::new((x + 12, y), 5, col.filled()));
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
    assert!(figure_has_axes(&buf, xl, yl), "figure_has_axes violated");
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
    let sxy: f64 = pts.iter().map(|p| (p.0 - mx) * (p.1 - my)).sum();
    let b = sxy / sxx;
    (my - b * mx, b)
}

/// Scatter of `pts` with its least-squares line, as one figure.
pub fn scatter_fit(labels: (&str, &str, &str), pts: &[(f64, f64)]) -> String {
    let (a, b) = fit(pts);
    let (x0, x1) = padded_range(pts.iter().map(|p| p.0));
    let line = [(x0, a + b * x0), (x1, a + b * x1)];
    svg(
        labels,
        &[
            Series { name: "observed", pts, line: false },
            Series { name: "least-squares fit", pts: &line, line: true },
        ],
    )
}

/// The SVG names both axis labels and draws mesh `<line>`s (the gridlines).
pub fn figure_has_axes(svg: &str, xl: &str, yl: &str) -> bool {
    let esc = |s: &str| s.replace('&', "&amp;").replace('<', "&lt;");
    svg.contains("<svg") && svg.contains(&esc(xl)) && svg.contains(&esc(yl)) && svg.contains("<line")
}

/// Write `svg` as `plot.svg` into `$ADS_OUT` when it is set; no-op otherwise.
pub fn write_if_out(svg: &str) {
    if let Ok(dir) = std::env::var("ADS_OUT") {
        std::fs::write(format!("{dir}/plot.svg"), svg).expect("plot.svg");
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
        let pts: Vec<_> = (0..5).map(|i| (i as f64, 2.0 + 3.0 * i as f64)).collect();
        let (a, b) = fit(&pts);
        assert!((a - 2.0).abs() < 1e-12 && (b - 3.0).abs() < 1e-12);
    }

    #[test]
    fn scatter_fit_has_axes_and_is_deterministic() {
        let pts: Vec<_> = (0..8).map(|i| (i as f64, (i * i) as f64)).collect();
        let l = ("t", "x (cm)", "y (g)");
        let (a, b) = (scatter_fit(l, &pts), scatter_fit(l, &pts));
        assert_eq!(a, b);
        assert!(figure_has_axes(&a, "x (cm)", "y (g)"));
        assert!(!figure_has_axes(&a, "missing label", "y (g)"));
    }

    #[test]
    #[should_panic(expected = "figure needs data")]
    fn empty_series_is_refused() {
        let _ = svg(("t", "x", "y"), &[]);
    }
}
