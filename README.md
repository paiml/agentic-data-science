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

## Run the gates

```bash
make gate
```

## Dataset licences

- Palmer Penguins: CC0 1.0 (Palmer Station LTER data policy).
- UCI Wine Quality: CC BY 4.0. Cortez, P. et al. (2009), doi:10.24432/C56S3T.

## Hero image

`scripts/hero.sh` draws `assets/hero.svg` from `datasets/penguins/penguins.csv` (one dot per row); `rmedia svg2png` renders `assets/hero.png`.
