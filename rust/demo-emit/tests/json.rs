use demo_emit::json::string;

#[test]
fn quotes_backslash_and_controls_are_escaped() {
    assert_eq!(string("a\"b\\c"), r#""a\"b\\c""#);
    assert_eq!(string("l1\nl2\tz"), r#""l1\nl2\tz""#);
    assert_eq!(string("\u{1}\u{1f}"), r#""\u0001\u001f""#);
}

#[test]
fn non_ascii_passes_through() {
    assert_eq!(string("é→"), "\"é→\"");
}
