//! Agentic Data Science, Course A (Rust).
pub mod p1;
pub mod p2;
pub mod p3;
pub mod p4;

/// Read a headed CSV file and map each data row's comma-split fields through `f`.
/// `what` names the file in the panic message when it cannot be read.
pub fn csv_map<T>(
    path: &str,
    what: &str,
    f: impl Fn(&[&str]) -> T,
) -> Vec<T> {
    std::fs::read_to_string(path)
        .expect(what)
        .lines()
        .skip(1)
        .map(|l| f(&l.split(',').collect::<Vec<_>>()))
        .collect()
}
