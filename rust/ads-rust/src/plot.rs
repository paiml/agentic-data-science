//! Text and SVG bar plots for the demo lessons (the Rust twin of `lean/.../Plot.lean`).
//!
//! Provable contracts: `plot_bars_bounded` (no bar is longer than the width, zero shows
//! nothing, nonzero shows something, the longest count fills the width) and
//! `plot_svg_bounded` (a non-empty chart, one rect per row plus the background, no bar
//! leaves the picture).

/// One chart row: a label and a count.
pub type Row = (String, usize);

/// A bar of `n` full blocks.
pub fn bar(n: usize) -> String {
    "█".repeat(n)
}

/// Blocks for count `n` when the largest count `m` gets `w` blocks; a nonzero count
/// always shows at least one block.
pub fn width(w: usize, m: usize, n: usize) -> usize {
    if n == 0 { 0 } else { (n * w / m.max(1)).max(1) }
}

fn max_count(rows: &[Row]) -> usize {
    rows.iter().map(|r| r.1).max().unwrap_or(0)
}

/// The printed lines for `rows`, after checking `plot_bars_bounded`.
pub fn plot_lines(w: usize, rows: &[Row]) -> Vec<String> {
    let m = max_count(rows);
    for (_, n) in rows {
        let k = width(w, m, *n);
        assert!(
            k <= w && (*n == 0) == (k == 0) && (*n != m || k == w),
            "plot_bars_bounded violated"
        );
    }
    rows.iter()
        .map(|(l, n)| format!("{l} {} {n}", bar(width(w, m, *n))))
        .collect()
}

/// Print the bars and the contract line.
pub fn plot(w: usize, rows: &[Row]) {
    for l in plot_lines(w, rows) {
        println!("{l}");
    }
    println!("contract: plot_bars_bounded OK");
}

/// XML text escape: the three reserved characters.
pub fn esc(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}

fn lbl(s: &str) -> String {
    esc(s.trim())
}

fn bar_x(rows: &[Row]) -> usize {
    1070 + 22
        * rows
            .iter()
            .map(|r| lbl(&r.0).chars().count())
            .max()
            .unwrap_or(0)
}

/// The rows as a 1920 by 1080 SVG, plot on the right half.
pub fn plot_svg(title: &str, w: usize, rows: &[Row]) -> String {
    let m = max_count(rows);
    let x0 = bar_x(rows);
    let px = 1700 - x0;
    let mut s = String::from(
        "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1920\" height=\"1080\" \
         viewBox=\"0 0 1920 1080\" role=\"img\" aria-labelledby=\"t d\">\n\
         <!-- GRID PROTOCOL MANIFEST: 1920x1080, plot in the right half, the left half is for the terminal -->\n",
    );
    s += &format!("<title id=\"t\">{}</title>\n", esc(title));
    s += "<desc id=\"d\">Bar chart, one bar per row.</desc>\n";
    s +=
        "<rect width=\"1920\" height=\"1080\" fill=\"#0b1020\"/>\n";
    s += &format!(
        "<text x=\"1020\" y=\"110\" font-size=\"44\" fill=\"#e5e7eb\">{}</text>\n",
        esc(title)
    );
    for (i, (l, n)) in rows.iter().enumerate() {
        let y = 190 + 80 * i;
        let k = px * width(w, m, *n) / w;
        s += &format!(
            "<text x=\"1020\" y=\"{}\" font-size=\"36\" fill=\"#e5e7eb\">{}</text>\n\
             <rect x=\"{x0}\" y=\"{y}\" width=\"{k}\" height=\"48\" fill=\"#4ade80\"/>\n\
             <text x=\"{}\" y=\"{}\" font-size=\"36\" fill=\"#e5e7eb\">{n}</text>\n",
            y + 38,
            lbl(l),
            x0 + 30 + k,
            y + 38
        );
    }
    s + "</svg>\n"
}

/// Write the SVG, then check `plot_svg_bounded`.
pub fn write_svg(
    path: &str,
    title: &str,
    w: usize,
    rows: &[Row],
) -> Result<(), String> {
    let s = plot_svg(title, w, rows);
    let m = max_count(rows);
    let x0 = bar_x(rows);
    let bad = rows.is_empty()
        || s.matches("<rect").count() != rows.len() + 1
        || s.matches("<text").count() != 2 * rows.len() + 1
        || 190 + 80 * rows.len() - 32 > 1080
        || rows.iter().any(|r| {
            x0 + (1700 - x0) * width(w, m, r.1) / w > 1700
        });
    if bad {
        return Err("plot_svg_bounded violated".into());
    }
    std::fs::write(path, &s).map_err(|e| e.to_string())?;
    println!("svg {} bars {path}", rows.len());
    println!("contract: plot_svg_bounded OK");
    Ok(())
}
