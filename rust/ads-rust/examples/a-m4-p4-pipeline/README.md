# A-M4-P4a: Wine Quality pipeline and report artifact (Rust)

Checks the RMSE against `datasets/golden/p4.json` and the artifact against `datasets/golden/p4-artifact.ttl`.

```bash
ADS_ROOT=$PWD cargo run --manifest-path rust/ads-rust/Cargo.toml --example a-m4-p4-pipeline
make gate-rust
```
