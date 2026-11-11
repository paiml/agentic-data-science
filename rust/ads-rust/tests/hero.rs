use ads_rust::anscombe::{parse, plot_svg};
use ads_rust::hero::{compose, from_dir};

fn plot() -> String {
    let csv =
        std::fs::read_to_string("../../data/anscombe/anscombe.csv")
            .expect("data");
    plot_svg(&parse(&csv).expect("parse"))
}

fn two() -> Vec<(String, String)> {
    vec![("rust".into(), plot()), ("julia".into(), plot())]
}

#[test]
fn compose_is_deterministic_and_wide_enough() {
    let (a, b) =
        (compose(&two()).unwrap(), compose(&two()).unwrap());
    assert_eq!(a, b);
    assert!(
        a.contains("width=\"1920\"")
            && a.contains("translate(960,0)")
    );
    assert!(a.contains(">rust<") && a.contains(">julia<"));
    assert!(!a.contains("<!--"));
}

#[test]
fn compose_refuses_empty_and_bad_panels() {
    assert!(compose(&[]).is_err());
    let bad = |s: &str| compose(&[("r".into(), s.into())]);
    assert!(bad("not svg").is_err());
    assert!(bad("<svg width=\"1\">").is_err());
    assert!(bad("<svg").is_err());
}

#[test]
fn from_dir_reads_each_landed_language_and_refuses_a_missing_one() {
    let d = tempfile::tempdir().unwrap();
    let p = d.path().to_str().unwrap();
    std::fs::create_dir(d.path().join("rust")).unwrap();
    std::fs::write(d.path().join("rust/plot.svg"), plot()).unwrap();
    assert!(from_dir(p, "rust\n\n").unwrap().contains(">rust<"));
    let e = from_dir(p, "rust\njulia\n").unwrap_err();
    assert!(e.contains("julia has no plot.svg"));
}

#[test]
fn an_xml_prolog_is_skipped_and_xlink_is_declared() {
    let cairo = format!(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n{}",
        plot()
    );
    let h = compose(&[("julia".into(), cairo)]).unwrap();
    assert!(!h.contains("<?xml"));
    assert!(h.starts_with(
        "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink="
    ));
    assert_eq!(h, compose(&[("julia".into(), plot())]).unwrap());
    let unclosed = "<?xml version=\"1.0\"";
    assert!(compose(&[("j".into(), unclosed.into())]).is_err());
}
