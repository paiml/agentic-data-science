//! Anscombe's quartet: shared sha256-pinned data, the summary lines every language must print
//! identically (ADS-DEMO-001 R-3, R-4) and a deterministic SVG scatter-with-fit (R-5, R-6).
use plotters::prelude::*;

/// Decimals every language prints (the declared parity precision).
pub const DECIMALS: usize = 2;
/// The four named sets of (x, y) points.
pub type Sets = Vec<(String, Vec<(f64, f64)>)>;
const SETS: [&str; 4] = ["I", "II", "III", "IV"];

/// Parse `set,x,y` rows into the four sets, in file order.
pub fn parse(csv: &str) -> Result<Sets, String> {
    let mut out: Sets =
        SETS.iter().map(|s| (s.to_string(), vec![])).collect();
    for (i, line) in csv.lines().enumerate().skip(1) {
        let f: Vec<&str> = line.split(',').collect();
        let [s, x, y] = f[..] else {
            return Err(format!("line {}: want 3 fields", i + 1));
        };
        let x: f64 = x
            .parse()
            .map_err(|_| format!("line {}: bad x", i + 1))?;
        let y: f64 = y
            .parse()
            .map_err(|_| format!("line {}: bad y", i + 1))?;
        let set = out
            .iter_mut()
            .find(|(n, _)| n == s)
            .ok_or(format!("line {}: unknown set {s}", i + 1))?;
        set.1.push((x, y));
    }
    Ok(out)
}

/// (mean x, mean y, slope, intercept, correlation) of one set.
pub fn stats(p: &[(f64, f64)]) -> (f64, f64, f64, f64, f64) {
    let n = p.len() as f64;
    let (mx, my) = (
        p.iter().map(|q| q.0).sum::<f64>() / n,
        p.iter().map(|q| q.1).sum::<f64>() / n,
    );
    let sxx: f64 = p.iter().map(|q| (q.0 - mx).powi(2)).sum();
    let syy: f64 = p.iter().map(|q| (q.1 - my).powi(2)).sum();
    let sxy: f64 = p.iter().map(|q| (q.0 - mx) * (q.1 - my)).sum();
    let b = sxy / sxx;
    (mx, my, b, my - b * mx, sxy / (sxx * syy).sqrt())
}

/// The stdout every language prints: one line per set, `DECIMALS` decimals.
pub fn report(sets: &[(String, Vec<(f64, f64)>)]) -> String {
    let mut s = String::new();
    for (name, p) in sets {
        let (mx, my, b, a, r) = stats(p);
        s += &format!(
            "set {name}: n={} mean_x={mx:.2} mean_y={my:.2} slope={b:.2} intercept={a:.2} r={r:.2}\n",
            p.len()
        );
    }
    s
}

/// Four panels, fixed 960x720, fixed fonts and colours, no clock, no randomness.
pub fn plot_svg(sets: &[(String, Vec<(f64, f64)>)]) -> String {
    let mut buf = String::new();
    {
        let root = SVGBackend::with_string(&mut buf, (960, 720))
            .into_drawing_area();
        root.fill(&WHITE).expect("svg backend writes to a String");
        let panels = root.split_evenly((2, 2));
        for (panel, (name, p)) in panels.iter().zip(sets) {
            let (_, _, b, a, _) = stats(p);
            let mut c = ChartBuilder::on(panel)
                .caption(format!("Set {name}"), ("sans-serif", 20))
                .margin(10)
                .x_label_area_size(30)
                .y_label_area_size(30)
                .build_cartesian_2d(0f64..20f64, 0f64..14f64)
                .expect("svg backend writes to a String");
            c.configure_mesh()
                .draw()
                .expect("svg backend writes to a String");
            c.draw_series(
                p.iter().map(|q| Circle::new(*q, 4, BLUE.filled())),
            )
            .expect("svg backend writes to a String");
            c.draw_series(LineSeries::new(
                [(3.0, a + b * 3.0), (19.0, a + b * 19.0)],
                &RED,
            ))
            .expect("svg backend writes to a String");
        }
        root.present().expect("svg backend writes to a String");
    }
    buf
}
