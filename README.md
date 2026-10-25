# Agentic Data Science: code examples

![Agentic Data Science](assets/hero.png)

Runnable, tested code examples for the **Agentic Data Science** specialization by Pragmatic AI Labs: the same four data science problems solved in five languages with an AI coding agent in the loop, under strict quality gates.

## The five courses

| Course | Language |
|---|---|
| C | R |
| B | Julia |
| D | Kotlin |
| A | Rust |
| E | Lean 4 |

Specialization: https://www.coursera.org/specialization/agentic-data-science (link goes live at launch).

## Layout

- `datasets/`: Palmer Penguins and UCI Wine Quality, each with LICENSE and SHA256SUMS; fixed folds, splits and centroids in `fixtures/`; golden reference numbers in `golden/`.
- `ontology/`: vocabulary and SHACL shapes that every example's `example.ttl` must satisfy.
- Language packages (`r/`, `julia/`, `kotlin/`, `rust/`, `lean/`) are added as each course's examples land.

## Installation

```bash
git clone https://github.com/paiml/agentic-data-science
cd agentic-data-science
cargo build --locked --manifest-path rust/ads-rust/Cargo.toml   # needs a stable Rust toolchain
```

The gates also need Apache Jena (`shacl`) on `PATH` and Java 17.

## Usage

```bash
cargo run -q --locked --manifest-path rust/ads-rust/Cargo.toml --example a-m1-p1
```

Each example under `rust/ads-rust/examples/` ends on a `contract: ... OK` line; `demos/` holds the scripted terminal runs used in the course videos.

## Run the gates

```bash
make gate
```

## Contributing

Open a pull request against `main`. Every change keeps `make gate` green (datasets, SHACL, Rust gate at 100% line and function coverage, clippy with `-D warnings`) and carries a test that fails when the behaviour breaks.

## License

MIT, see `LICENSE`. Datasets keep their own licences, below.

## Dataset licences

- Palmer Penguins: CC0 1.0 (Palmer Station LTER data policy).
- UCI Wine Quality: CC BY 4.0. Cortez, P. et al. (2009), doi:10.24432/C56S3T.

## Hero image

`scripts/hero.sh` draws `assets/hero.svg` from `datasets/penguins/penguins.csv` (one dot per row); `rmedia svg2png` renders `assets/hero.png`.
