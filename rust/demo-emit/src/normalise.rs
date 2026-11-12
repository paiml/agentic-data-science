//! Output normalisation and the leak refusal.

/// The absolute spellings the output is rewritten from.
#[derive(Debug, Clone, Default)]
pub struct Roots {
    pub target: Vec<String>,
    pub root: Vec<String>,
    pub host: Vec<String>,
}

pub fn strip_terminal(_s: &str) -> String {
    todo!("RED")
}

pub fn normalise(_s: &str, _roots: &Roots) -> String {
    todo!("RED")
}

#[derive(Debug, PartialEq, Eq)]
pub struct Leak {
    pub line: usize,
    pub reason: String,
}

pub fn find_leak(_s: &str, _roots: &Roots) -> Option<Leak> {
    todo!("RED")
}

#[derive(Debug, PartialEq, Eq)]
pub struct TestFacts {
    pub passed: u64,
    pub failed: u64,
    pub ignored: u64,
}

/// Sum the `test result:` lines; `Err(reason)` when there is none or the facts are not acceptable.
pub fn test_facts(_s: &str) -> Result<TestFacts, String> {
    todo!("RED")
}

pub fn is_cargo_test(_program: &str, _args: &[String]) -> bool {
    todo!("RED")
}
