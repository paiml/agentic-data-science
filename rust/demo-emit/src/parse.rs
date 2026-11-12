//! The closed form of a `.cmds` line.

/// The programs a row may run: the first words of the committed rows.
pub const ALLOWED_PROGRAMS: &[&str] = &["bat", "cargo"];

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FormKind {
    EmptyFile,
    EmptyLine,
    BadByte(u8),
    Assignment(String),
    BadProgramWord(String),
    ProgramNotAllowed(String),
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

/// Parse every line of a `.cmds` file; the first refusal wins.
pub fn parse_cmds(
    _bytes: &[u8],
    _allow: &[&str],
) -> Result<Vec<Line>, FormError> {
    todo!("RED")
}
