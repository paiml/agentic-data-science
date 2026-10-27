# play-lean receipt (2026-10-27)
- Playground file: playground/lean/e-m1-p1-mean.lean sha256 e7a90bedcf22afdc8c6607c010663f3f8ea5672c5cb36d12613dda3bc4f02291; URL 2464 chars (hash arg #code=, jq @uri).
- Clean: `lean +v4.35.0 -DwarningAsError=true` exit 0, prints "contract: mean_shift OK".
- Planted: runtime violation variant exit 1 (contract mean_shift violated); proof-broken variant exit 1 (elaboration error, not a bare sorry).
- Lab labs/e-final: tests/run.sh starter exit 1 (FAIL test1,2,3), solution exit 0 (PASS 1,2,3); 3 tests.
- NOT RUN: live.lean-lang.org browser check on :99; whether the site's Lean version/core accepts the file; Coursera lab runtime (Δ5). Mathlib theorems (Stats.lean) not flattened: no local Mathlib build.
- Held: nothing published, no ticket, PR not armed.
