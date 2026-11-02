# A-M2-P2: species model (linfa-linear) and fixed-fold CV (Rust)

Checks the result against `datasets/golden/p2.json`.

```bash
ADS_ROOT=$PWD cargo run --manifest-path rust/ads-rust/Cargo.toml --example a-m2-p2-cv
make gate-rust
```
