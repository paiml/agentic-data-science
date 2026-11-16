# A-M1-P1a: typed ingest and NA policy (Rust)

Loads the CSV with Float64 measurement columns via polars and drops rows with a missing numeric measurement
(344 rows become 342; a missing `sex` alone keeps the row).

```bash
ADS_ROOT=$PWD cargo run --manifest-path rust/ads-rust/Cargo.toml --example a-m1-p1
make gate-rust
```
