# play-lean receipt (2026-10-27)
- Playground file: playground/lean/e-m1-p1-mean.lean sha256 e7a90bedcf22afdc8c6607c010663f3f8ea5672c5cb36d12613dda3bc4f02291; URL 2464 chars (hash arg #code=, jq @uri).
- Clean: `lean +v4.35.0 -DwarningAsError=true` exit 0, prints "contract: mean_shift OK".
- Planted: runtime violation variant exit 1 (contract mean_shift violated); proof-broken variant exit 1 (elaboration error, not a bare sorry).
- Lab labs/e-final: tests/run.sh starter exit 1 (keyword layer refuses the sorry before any compile; 7 tests run), solution exit 0 (PASS tests 1-9: sorry scan, Lean-parser command allowlist, 5 keyword pre-filters, compile+Grade.lean verdict, axioms). tests/falsify-toolchain.sh: 30 cheats, 11 parser-only arms, 12 root-layer arms. Limits: GRADER_TIMEOUT (120 s), GRADER_MEM_MB (4096, lean -M); bwrap fallback prints a WARNING UNSANDBOXED line.
- NOT RUN: live.lean-lang.org browser check on :99; whether the site's Lean version/core accepts the file; Coursera lab runtime (Δ5). Mathlib theorems (Stats.lean) not flattened: no local Mathlib build.
- Held: nothing published, no ticket, PR not armed.
