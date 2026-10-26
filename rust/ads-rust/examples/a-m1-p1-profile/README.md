# A-M1-P1b: per-species profile and golden JSON (Rust)

Polars lazy group-by over the cleaned frame: n, mean and sample SD (n-1) per species for the four measurements,
checked against `datasets/golden/p1.json` within 1e-9.

```bash
ADS_ROOT=$PWD cargo run --manifest-path rust/ads-rust/Cargo.toml --example a-m1-p1-profile
make gate-rust
```
