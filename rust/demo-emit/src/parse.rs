//! The closed form of a `.cmds` line.
//!
//! A line is a program word followed by arguments, separated by ASCII
//! space or tab. No shell ever reads it, so the form is closed by an
//! alphabet, not by a deny-list: a byte outside the alphabet refuses
//! the whole file. The program word must also be on a short allow-list.

/// The programs a row may run: the first words of the committed rows.
pub const ALLOWED_PROGRAMS: &[&str] = &["bat", "cargo", "make"];

/// The only `make` invocations a row may type: `make <target>` with
/// exactly one argument from this list. `make` starts the recipe's
/// shell, so this is the one place a shell runs; it is bounded to the
/// repo-owned targets named here and to nothing a row can add.
pub const MAKE_TARGETS: &[&str] = &["gate-shacl", "gate-rust"];

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FormKind {
    EmptyFile,
    EmptyLine,
    BadByte(u8),
    Assignment(String),
    BadProgramWord(String),
    ProgramNotAllowed(String),
    MakeNotAllowed(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FormError {
    pub line: usize,
    pub kind: FormKind,
}

impl std::fmt::Display for FormError {
    fn fmt(
        &self,
        f: &mut std::fmt::Formatter<'_>,
    ) -> std::fmt::Result {
        write!(f, "line {}: {:?}", self.line, self.kind)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Line {
    pub number: usize,
    pub raw: String,
    pub program: String,
    pub args: Vec<String>,
}

fn alphabet(b: u8) -> bool {
    b.is_ascii_alphanumeric() || b"_./:=,+@-".contains(&b)
}

fn program_word(b: u8) -> bool {
    b.is_ascii_alphanumeric() || b == b'_' || b == b'-'
}

fn bad_byte(raw: &[u8]) -> Option<u8> {
    raw.iter()
        .copied()
        .find(|b| !alphabet(*b) && *b != b' ' && *b != b'\t')
}

/// One line: its bytes, then its program word, then the allow-list.
fn parse_line(
    number: usize,
    raw: &[u8],
    allow: &[&str],
) -> Result<Line, FormError> {
    let err = |kind| FormError { line: number, kind };
    if let Some(b) = bad_byte(raw) {
        return Err(err(FormKind::BadByte(b)));
    }
    // Every byte is ASCII here, so this cannot fail.
    let text = std::str::from_utf8(raw)
        .map_err(|_| err(FormKind::BadByte(0x80)))?;
    let mut words = text
        .split([' ', '\t'])
        .filter(|w| !w.is_empty())
        .map(str::to_string);
    let program =
        words.next().ok_or_else(|| err(FormKind::EmptyLine))?;
    if program.contains('=') {
        return Err(err(FormKind::Assignment(program)));
    }
    if !program.bytes().all(program_word) {
        return Err(err(FormKind::BadProgramWord(program)));
    }
    if !allow.contains(&program.as_str()) {
        return Err(err(FormKind::ProgramNotAllowed(program)));
    }
    let args: Vec<String> = words.collect();
    if program == "make"
        && !matches!(args.as_slice(), [t] if MAKE_TARGETS.contains(&t.as_str()))
    {
        return Err(err(FormKind::MakeNotAllowed(args.join(" "))));
    }
    Ok(Line {
        number,
        raw: text.to_string(),
        program,
        args,
    })
}

/// Parse every line of a `.cmds` file; the first refusal wins.
pub fn parse_cmds(
    bytes: &[u8],
    allow: &[&str],
) -> Result<Vec<Line>, FormError> {
    if bytes.is_empty() {
        return Err(FormError {
            line: 1,
            kind: FormKind::EmptyFile,
        });
    }
    let body = bytes.strip_suffix(b"\n").unwrap_or(bytes);
    body.split(|b| *b == b'\n')
        .enumerate()
        .map(|(i, raw)| parse_line(i + 1, raw, allow))
        .collect()
}
