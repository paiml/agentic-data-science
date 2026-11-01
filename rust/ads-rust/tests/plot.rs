use ads_rust::plot::*;

fn rows() -> Vec<Row> {
    vec![
        ("Adelie".into(), 151),
        ("Chinstrap".into(), 68),
        ("Gentoo".into(), 123),
        ("None".into(), 0),
        ("One".into(), 1),
    ]
}

#[test]
fn bar_length_is_its_value() {
    assert_eq!(bar(5).chars().count(), 5);
    assert_eq!(bar(0), "");
}

#[test]
fn width_scales_and_never_hides_a_nonzero_count() {
    assert_eq!(width(40, 151, 0), 0);
    assert_eq!(width(40, 151, 151), 40);
    assert_eq!(width(40, 151, 1), 1);
    assert_eq!(width(40, 0, 0), 0);
}

#[test]
fn plot_lines_carry_label_bar_and_count() {
    let l = plot_lines(40, &rows());
    assert_eq!(l.len(), 5);
    assert!(l[0].starts_with("Adelie ") && l[0].ends_with(" 151"));
    assert_eq!(l[0].matches('█').count(), 40);
    assert_eq!(l[3], "None  0");
    plot(40, &rows());
}

#[test]
fn an_empty_plot_has_no_lines() {
    assert!(plot_lines(40, &[]).is_empty());
}

#[test]
fn escape_covers_the_three_reserved_characters() {
    assert_eq!(esc("a&b<c>d"), "a&amp;b&lt;c&gt;d");
}

#[test]
fn the_svg_has_one_rect_per_row_plus_the_background() {
    let s = plot_svg("Rows <kept>", 40, &rows());
    assert_eq!(s.matches("<rect").count(), 6);
    assert!(s.contains("Rows &lt;kept&gt;"));
}

#[test]
fn write_svg_writes_a_bounded_chart() {
    let d = tempfile::tempdir().unwrap();
    let p = d.path().join("c.svg");
    write_svg(p.to_str().unwrap(), "t", 40, &rows()).unwrap();
    assert!(
        std::fs::read_to_string(&p).unwrap().starts_with("<svg")
    );
}

#[test]
fn write_svg_refuses_an_empty_chart() {
    assert_eq!(
        write_svg("/nonexistent/x.svg", "t", 40, &[]),
        Err("plot_svg_bounded violated".to_string())
    );
}

#[test]
fn write_svg_reports_an_unwritable_path() {
    assert!(
        write_svg("/nonexistent/x.svg", "t", 40, &rows()).is_err()
    );
}

#[test]
fn too_many_rows_leave_the_picture() {
    let many: Vec<Row> =
        (0..14).map(|i| (format!("r{i}"), i + 1)).collect();
    assert!(
        write_svg("/nonexistent/x.svg", "t", 40, &many).is_err()
    );
}
