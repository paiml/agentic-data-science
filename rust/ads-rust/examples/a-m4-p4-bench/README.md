# A-M4-P4b: polars vs BTreeMap grouped mean (Rust)

Checks that both engines return the same per-colour aggregate, then times them. Timings vary by machine and are never part of a parity check.

```bash
ADS_ROOT=$PWD cargo run --manifest-path rust/ads-rust/Cargo.toml --example a-m4-p4-bench
make gate-rust
```
