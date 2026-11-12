//! Output normalisation and the leak refusal.
//!
//! Normalisation rewrites the volatile parts of cargo and test output
//! to fixed tokens. The leak scan then refuses anything volatile that
//! is left: a host path, or a long hex run that is not a pinned token.

/// The absolute spellings the output is rewritten from.
#[derive(Debug, Clone, Default)]
pub struct Roots {
    /// Spellings of the cargo target directory: become `target`.
    pub target: Vec<String>,
    /// Spellings of the checkout root: become `.`.
    pub root: Vec<String>,
    /// Literal host paths that must not survive in the output.
    pub host: Vec<String>,
}

type Chars<'a> = std::iter::Peekable<std::str::Chars<'a>>;

fn skip_csi(it: &mut Chars) {
    for d in it.by_ref() {
        if ('\u{40}'..='\u{7e}').contains(&d) {
            return;
        }
    }
}

fn skip_osc(it: &mut Chars) {
    while let Some(d) = it.next() {
        if d == '\u{7}' {
            return;
        }
        if d == '\u{1b}' {
            it.next();
            return;
        }
    }
}

/// Drop ANSI escape sequences and carriage returns.
pub fn strip_terminal(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut it = s.chars().peekable();
    while let Some(c) = it.next() {
        match c {
            '\r' => {}
            '\u{1b}' => match it.next() {
                Some('[') => skip_csi(&mut it),
                Some(']') => skip_osc(&mut it),
                _ => {}
            },
            c => out.push(c),
        }
    }
    out
}

fn path_char(b: u8) -> bool {
    b.is_ascii_alphanumeric() || b"_.~/-".contains(&b)
}

fn name_char(b: u8) -> bool {
    b.is_ascii_alphanumeric() || b"_.-".contains(&b)
}

/// Copy the char at byte `*i` of `s` to `out` and step over it.
fn copy_char(out: &mut String, s: &str, i: &mut usize) {
    let c = s[*i..].chars().next().unwrap_or(' ');
    out.push(c);
    *i += c.len_utf8();
}

/// The longest spelling that matches at `i` on a path boundary.
fn root_at<'a>(
    b: &[u8],
    i: usize,
    sp: &[(&str, &'a str)],
) -> Option<(usize, &'a str)> {
    if b[i] != b'/' || (i > 0 && path_char(b[i - 1])) {
        return None;
    }
    sp.iter()
        .find(|(p, _)| {
            b[i..].starts_with(p.as_bytes())
                && b.get(i + p.len()).is_none_or(|n| !name_char(*n))
        })
        .map(|(p, rep)| (p.len(), *rep))
}

/// N1: replace each root spelling, longest first, only at a path
/// boundary.
fn replace_roots(s: &str, roots: &Roots) -> String {
    let mut sp: Vec<(&str, &str)> = Vec::new();
    let all = [(&roots.target, "target"), (&roots.root, ".")];
    for (list, rep) in all {
        for p in list {
            let p = p.trim_end_matches('/');
            if !p.is_empty() {
                sp.push((p, rep));
            }
        }
    }
    sp.sort_by_key(|(p, _)| std::cmp::Reverse(p.len()));
    let b = s.as_bytes();
    let mut out = String::with_capacity(s.len());
    let mut i = 0;
    while i < b.len() {
        match root_at(b, i, &sp) {
            Some((n, rep)) => {
                out.push_str(rep);
                i += n;
            }
            None => copy_char(&mut out, s, &mut i),
        }
    }
    out
}

const PROGRESS: &[&str] = &[
    "Compiling",
    "Checking",
    "Fresh",
    "Downloading",
    "Downloaded",
    "Blocking",
    "Updating",
    "Locking",
    "Adding",
    "Unpacking",
];

/// N2: a cargo status line has its verb right-aligned in 12 columns.
fn is_progress(line: &str) -> bool {
    let rest = line.trim_start_matches(' ');
    let lead = line.len() - rest.len();
    PROGRESS.iter().any(|v| {
        rest.strip_prefix(v).is_some_and(|r| r.starts_with(' '))
            && lead + v.len() == 12
    })
}

fn is_hex(b: u8) -> bool {
    b.is_ascii_hexdigit()
}

fn token_char(c: u8) -> bool {
    c.is_ascii_alphanumeric() || b"_.+/-".contains(&c)
}

/// Zero every `-<16 hex>` inside `b[start..end]`.
fn zero_hashes(b: &mut [u8], start: usize, end: usize) {
    let mut j = start;
    while j + 17 <= end {
        let hash = b[j] == b'-'
            && b[j + 1..j + 17].iter().all(|c| is_hex(*c));
        let after = b.get(j + 17).is_none_or(|c| {
            !(c.is_ascii_alphanumeric() || *c == b'_')
        });
        if hash && after {
            b[j + 1..j + 17].fill(b'0');
            j += 17;
        } else {
            j += 1;
        }
    }
}

/// N3: `-<16 hex>` at the end of a path token that starts at
/// `target/` becomes sixteen zeros.
fn pin_target_hashes(line: &str) -> String {
    let mut b = line.as_bytes().to_vec();
    let mut i = 0;
    while i + 7 <= b.len() {
        if &b[i..i + 7] != b"target/"
            || (i > 0 && path_char(b[i - 1]))
        {
            i += 1;
            continue;
        }
        let end = (i..b.len())
            .find(|k| !token_char(b[*k]))
            .unwrap_or(b.len());
        zero_hashes(&mut b, i, end);
        i = end.max(i + 7);
    }
    String::from_utf8(b).unwrap_or_else(|_| line.to_string())
}

fn digits_end(b: &[u8], mut j: usize) -> usize {
    while b.get(j).is_some_and(u8::is_ascii_digit) {
        j += 1;
    }
    j
}

/// The end of `N` or `N.N` at `i`, if a number starts there.
fn number_end(b: &[u8], i: usize) -> Option<usize> {
    let j = digits_end(b, i);
    if j == i {
        return None;
    }
    if b.get(j) != Some(&b'.') {
        return Some(j);
    }
    let k = digits_end(b, j + 1);
    Some(if k > j + 1 { k } else { j })
}

/// The end of ` in <number>s` at `i`, if it is there and whole.
fn duration_end(b: &[u8], i: usize) -> Option<usize> {
    if !b[i..].starts_with(b" in ") {
        return None;
    }
    let j = number_end(b, i + 4)?;
    let whole = b
        .get(j + 1)
        .is_none_or(|n| !(n.is_ascii_alphanumeric() || *n == b'_'));
    (b.get(j) == Some(&b's') && whole).then_some(j + 1)
}

/// N3: ` in 12.34s` becomes ` in 0.00s`.
fn pin_durations(line: &str) -> String {
    let b = line.as_bytes();
    let mut out = String::with_capacity(line.len());
    let mut i = 0;
    while i < b.len() {
        match duration_end(b, i) {
            Some(end) => {
                out.push_str(" in 0.00s");
                i = end;
            }
            None => copy_char(&mut out, line, &mut i),
        }
    }
    out
}

fn is_decimal(n: &str) -> bool {
    let dots = n.bytes().filter(|c| *c == b'.').count();
    n.bytes().all(|c| c.is_ascii_digit() || c == b'.')
        && dots <= 1
        && n.bytes().next().is_some_and(|c| c.is_ascii_digit())
}

/// N3: `   polars: 12.345678 ms` and `btreemap:` lines from the bench.
fn pin_engine_line(line: &str) -> Option<String> {
    let rest = line.trim_start_matches(' ');
    let lead = &line[..line.len() - rest.len()];
    ["polars:", "btreemap:"].iter().find_map(|label| {
        let after = rest.strip_prefix(label)?;
        let num = after.trim_start_matches(' ');
        let gap = &after[..after.len() - num.len()];
        is_decimal(num.strip_suffix(" ms")?)
            .then(|| format!("{lead}{label}{gap}0.000000 ms"))
    })
}

/// `commit=<40 hex>` at `i`, whole.
fn commit_at(b: &[u8], i: usize) -> bool {
    b[i..].starts_with(b"commit=")
        && b.len() >= i + 47
        && b[i + 7..i + 47].iter().all(|c| is_hex(*c))
        && b.get(i + 47).is_none_or(|n| !n.is_ascii_alphanumeric())
}

/// N3: `commit=<40 hex>` becomes forty zeros.
fn pin_commit(line: &str) -> String {
    let b = line.as_bytes();
    let mut out = String::with_capacity(line.len());
    let mut i = 0;
    while i < b.len() {
        if commit_at(b, i) {
            out.push_str("commit=");
            out.push_str(&"0".repeat(40));
            i += 47;
        } else {
            copy_char(&mut out, line, &mut i);
        }
    }
    out
}

fn pin_line(line: &str) -> String {
    match pin_engine_line(line) {
        Some(l) => l,
        None => {
            pin_commit(&pin_durations(&pin_target_hashes(line)))
        }
    }
}

pub fn normalise(s: &str, roots: &Roots) -> String {
    let s = replace_roots(s, roots);
    let mut out = String::with_capacity(s.len());
    for piece in s.split_inclusive('\n') {
        let line = piece.strip_suffix('\n').unwrap_or(piece);
        if is_progress(line) {
            continue;
        }
        out.push_str(&pin_line(line));
        if piece.ends_with('\n') {
            out.push('\n');
        }
    }
    out
}

#[derive(Debug, PartialEq, Eq)]
pub struct Leak {
    pub line: usize,
    pub reason: String,
}

const HOST_PREFIXES: &[&str] = &[
    "home",
    "tmp",
    "root",
    "Users",
    "runner",
    "github",
    "__w",
    "mnt",
    "var/folders",
    "private",
];

fn word_char(b: u8) -> bool {
    b.is_ascii_alphanumeric() || b == b'_'
}

/// A host prefix right after the `/` at `i`.
fn prefix_at(b: &[u8], i: usize) -> Option<&'static str> {
    if b[i] != b'/'
        || (i > 0
            && (word_char(b[i - 1]) || b".~-".contains(&b[i - 1])))
    {
        return None;
    }
    HOST_PREFIXES.iter().copied().find(|p| {
        b[i + 1..].starts_with(p.as_bytes())
            && b.get(i + 1 + p.len()).is_none_or(|n| !word_char(*n))
    })
}

fn host_prefix(line: &str) -> Option<&'static str> {
    let b = line.as_bytes();
    (0..b.len()).find_map(|i| prefix_at(b, i))
}

fn num_char(b: u8) -> bool {
    b.is_ascii_alphanumeric() || b"_.+-".contains(&b)
}

fn whole(b: &[u8], end: usize) -> bool {
    b.get(end).is_none_or(|n| !num_char(*n))
}

/// The end of `[eE][+-]?[0-9]{1,3}` at `j`, if it is there and whole.
fn exponent_end(b: &[u8], j: usize) -> Option<usize> {
    if !matches!(b.get(j), Some(b'e') | Some(b'E')) {
        return None;
    }
    let sign = matches!(b.get(j + 1), Some(b'+') | Some(b'-'));
    let e0 = j + 1 + usize::from(sign);
    let k = digits_end(b, e0);
    (k > e0 && k - e0 <= 3 && whole(b, k)).then_some(k)
}

/// The end of a whole decimal literal starting at `i`:
/// `[+-]?[0-9]{1,15}\.[0-9]+([eE][+-]?[0-9]{1,3})?`, not glued to a
/// longer token on either side.
fn decimal_at(b: &[u8], i: usize) -> Option<usize> {
    if i > 0 && num_char(b[i - 1]) {
        return None;
    }
    let d0 = i + usize::from(matches!(
        b.get(i),
        Some(b'+') | Some(b'-')
    ));
    let j = digits_end(b, d0);
    if j == d0 || j - d0 > 15 || b.get(j) != Some(&b'.') {
        return None;
    }
    let f = digits_end(b, j + 1);
    if f == j + 1 {
        return None;
    }
    exponent_end(b, f).or_else(|| whole(b, f).then_some(f))
}

/// Blank every whole decimal literal.
fn blank_decimals(line: &str) -> Vec<u8> {
    let b = line.as_bytes();
    let mut out = b.to_vec();
    let mut i = 0;
    while i < b.len() {
        match decimal_at(b, i) {
            Some(end) => {
                out[i..end].fill(b' ');
                i = end;
            }
            None => i += 1,
        }
    }
    out
}

fn hex_run_end(b: &[u8], s: usize) -> usize {
    (s..b.len()).find(|k| !is_hex(b[*k])).unwrap_or(b.len())
}

/// A hex run of 16 or more that is not exactly 16 or 40 zeros.
fn bad_hex_run(b: &[u8]) -> Option<usize> {
    let mut i = 0;
    while i < b.len() {
        let end = hex_run_end(b, i);
        let run = &b[i..end];
        let pinned = run.iter().all(|c| *c == b'0')
            && matches!(run.len(), 16 | 40);
        if run.len() >= 16 && !pinned {
            return Some(i);
        }
        i = end.max(i + 1);
    }
    None
}

fn line_leak(line: &str, hosts: &[&str]) -> Option<String> {
    if let Some(h) = hosts.iter().find(|h| line.contains(**h)) {
        return Some(format!("host path {h:?}"));
    }
    if let Some(p) = host_prefix(line) {
        return Some(format!("host path prefix /{p}"));
    }
    bad_hex_run(&blank_decimals(line))
        .map(|at| format!("hex run at column {}", at + 1))
}

pub fn find_leak(s: &str, roots: &Roots) -> Option<Leak> {
    let hosts: Vec<&str> = roots
        .host
        .iter()
        .map(|h| h.as_str())
        .filter(|h| !h.is_empty())
        .collect();
    s.split('\n').enumerate().find_map(|(i, line)| {
        line_leak(line, &hosts).map(|reason| Leak {
            line: i + 1,
            reason,
        })
    })
}

#[derive(Debug, PartialEq, Eq)]
pub struct TestFacts {
    pub passed: u64,
    pub failed: u64,
    pub ignored: u64,
}

fn count_before(seg: &str, word: &str) -> Option<u64> {
    seg.trim().strip_suffix(word)?.trim().parse().ok()
}

fn first_count(counts: &str, word: &str) -> Option<u64> {
    counts.split(';').find_map(|seg| count_before(seg, word))
}

fn result_line(line: &str) -> Option<Result<TestFacts, String>> {
    let rest = line.strip_prefix("test result: ")?;
    let bad = || format!("unreadable result line: {line}");
    let Some((_, counts)) = rest.split_once(' ') else {
        return Some(Err(bad()));
    };
    let facts = (
        first_count(counts, "passed"),
        first_count(counts, "failed"),
        first_count(counts, "ignored"),
    );
    Some(match facts {
        (Some(passed), Some(failed), Some(ignored)) => {
            Ok(TestFacts {
                passed,
                failed,
                ignored,
            })
        }
        _ => Err(bad()),
    })
}

/// Sum the `test result:` lines; `Err(reason)` when there is none or
/// the facts are not acceptable.
pub fn test_facts(s: &str) -> Result<TestFacts, String> {
    let mut f = TestFacts {
        passed: 0,
        failed: 0,
        ignored: 0,
    };
    let mut seen = 0;
    for r in s.lines().filter_map(result_line) {
        let r = r?;
        f.passed += r.passed;
        f.failed += r.failed;
        f.ignored += r.ignored;
        seen += 1;
    }
    if seen == 0 {
        return Err("no `test result:` line".to_string());
    }
    if f.failed > 0 {
        return Err(format!("{} test(s) failed", f.failed));
    }
    if f.ignored > 0 {
        return Err(format!("{} test(s) ignored", f.ignored));
    }
    if f.passed == 0 {
        return Err("no test passed".to_string());
    }
    Ok(f)
}

/// `cargo [flags] test ...`: the first word not starting with `-` or
/// `+` is the subcommand.
pub fn is_cargo_test(program: &str, args: &[String]) -> bool {
    program == "cargo"
        && args
            .iter()
            .find(|a| !a.starts_with('-') && !a.starts_with('+'))
            .is_some_and(|a| a == "test")
}
