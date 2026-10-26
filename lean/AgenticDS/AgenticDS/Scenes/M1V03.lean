import Mathlib
/-! The toolchain pin and the cache. -/

-- One exact release is pinned, so every machine builds
-- with the same compiler.
def m1v03_pin : IO String :=
  IO.FS.readFile "lean-toolchain"

-- Mathlib arrives prebuilt (lake exe cache get); the
-- terminal runs `lake build` itself.
def m1v03 : IO Unit := do
  IO.print (← m1v03_pin)
