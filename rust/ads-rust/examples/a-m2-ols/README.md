# A-M2-P2: OLS with aprender (Rust)

Loads the penguins CSV with polars, applies the NA policy (342 rows), fits body mass on flipper length with aprender's
`LinearRegression`, draws the species scatter and the fitted line in the terminal with aprender's visualisation crate,
and checks the line against `datasets/golden/p2.json` within an absolute tolerance of 1e-2.

```bash
cd rust/ads-rust
cargo run
cd ../..
make gate-rust
```

Set `ADS_PLOT_PANE` to a terminal device or FIFO to send the chart to a side pane instead of stdout.
