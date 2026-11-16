//! Hero image (ADS-DEMO-001 R-9): one deterministic composite of every landed
//! language's Anscombe `plot.svg`, side by side, labelled by language.
//!
//! Provable contract: the same panels in the same order give the same bytes;
//! a panel that is not a plain `<svg>…</svg>` document is refused, never skipped.

/// Width and height of one canonical plot panel (see `anscombe::plot_svg`).
pub const PANEL: (u32, u32) = (960, 720);
/// Height of the language label band under each panel.
pub const LABEL: u32 = 48;

/// Compose `(language, plot.svg)` panels left to right into one SVG.
pub fn compose(
    panels: &[(String, String)],
) -> Result<String, String> {
    if panels.is_empty() {
        return Err("hero: no panels".into());
    }
    let (w, h) = (PANEL.0 * panels.len() as u32, PANEL.1 + LABEL);
    let mut out = format!(
        "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"{w}\" height=\"{h}\" viewBox=\"0 0 {w} {h}\">\n<rect width=\"{w}\" height=\"{h}\" fill=\"#ffffff\"/>\n"
    );
    for (i, (lang, svg)) in panels.iter().enumerate() {
        let body = inner(lang, svg)?;
        let x = PANEL.0 * i as u32;
        out.push_str(&format!(
            "<g transform=\"translate({x},0)\">\n{body}\n</g>\n<text x=\"{}\" y=\"{}\" text-anchor=\"middle\" font-family=\"sans-serif\" font-size=\"28\">{lang}</text>\n",
            x + PANEL.0 / 2,
            PANEL.1 + 34
        ));
    }
    out.push_str("</svg>\n");
    Ok(out)
}

/// The content of a plain `<svg …>…</svg>` document.
fn inner<'a>(lang: &str, svg: &'a str) -> Result<&'a str, String> {
    // A writer may open with an `<?xml …?>` prolog (CairoMakie does); only the `<svg>` element is kept.
    let t = svg.trim();
    let t = t
        .strip_prefix("<?xml")
        .and_then(|r| r.split_once("?>"))
        .map_or(t, |(_, rest)| rest.trim_start());
    let open_end = t
        .starts_with("<svg")
        .then(|| t.find('>'))
        .flatten()
        .ok_or_else(|| {
            format!(
                "hero: {lang} plot.svg is not an <svg> document"
            )
        })?;
    t[open_end + 1..].strip_suffix("</svg>").ok_or_else(|| {
        format!("hero: {lang} plot.svg has no closing </svg>")
    })
}

/// Build the hero from `<dir>/<lang>/plot.svg` for each language in `landed`
/// (one per line). A landed language with no plot is an error (never skipped).
pub fn from_dir(dir: &str, landed: &str) -> Result<String, String> {
    let panels = landed
        .lines()
        .filter(|l| !l.is_empty())
        .map(|l| {
            std::fs::read_to_string(format!("{dir}/{l}/plot.svg"))
                .map(|s| (l.to_string(), s))
                .map_err(|e| format!("hero: landed language {l} has no plot.svg ({e})"))
        })
        .collect::<Result<Vec<_>, _>>()?;
    compose(&panels)
}
