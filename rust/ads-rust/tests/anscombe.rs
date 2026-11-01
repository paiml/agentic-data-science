use ads_rust::anscombe::{parse, plot_svg, report, stats};

fn data() -> String {
    std::fs::read_to_string("../../data/anscombe/anscombe.csv")
        .expect("data")
}

#[test]
fn the_quartet_has_four_sets_of_eleven() {
    let s = parse(&data()).expect("parse");
    assert_eq!(s.len(), 4);
    assert!(s.iter().all(|(_, p)| p.len() == 11));
}

#[test]
fn every_set_prints_the_same_summary() {
    let r = report(&parse(&data()).expect("parse"));
    assert_eq!(r.lines().count(), 4);
    assert!(r.contains(
        "mean_x=9.00 mean_y=7.50 slope=0.50 intercept=3.00 r=0.82"
    ));
}

#[test]
fn stats_of_a_perfect_line() {
    let (mx, my, b, a, r) =
        stats(&[(0.0, 1.0), (1.0, 3.0), (2.0, 5.0)]);
    assert_eq!((mx, my, b, a), (1.0, 3.0, 2.0, 1.0));
    assert!((r - 1.0).abs() < 1e-12);
}

#[test]
fn parse_refuses_bad_rows() {
    assert!(parse("set,x,y\nI,1").is_err());
    assert!(parse("set,x,y\nI,a,1").is_err());
    assert!(parse("set,x,y\nI,1,b").is_err());
    assert!(parse("set,x,y\nV,1,1").is_err());
}

#[test]
fn the_svg_is_deterministic_and_clockless() {
    let s = parse(&data()).expect("parse");
    let (a, b) = (plot_svg(&s), plot_svg(&s));
    assert_eq!(a, b);
    assert!(a.starts_with("<svg") && a.contains("Set IV"));
    assert!(!a.contains("<!--"));
}
