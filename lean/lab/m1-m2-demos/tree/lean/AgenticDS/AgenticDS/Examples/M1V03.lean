import AgenticDS.Examples.M1Data
/-! The toolchain pin and the cache. -/

-- One exact release is pinned, so every machine builds
-- with the same compiler.
def m1v03_pin : IO String :=
  IO.FS.readFile "lean-toolchain"

-- Mathlib arrives prebuilt (lake exe cache get); the
-- you run `lake build` yourself.
def m1v03 : IO Unit := do
  IO.print (← m1v03_pin)
  -- Real data: lines in the three files that pin the build.
  let fs := ["lean-toolchain", "lakefile.toml",
    "lake-manifest.json"]
  let ns ← fs.mapM fun f => do
    pure (AgenticDS.nLines (← IO.FS.readFile f))
  for (f, n) in fs.zip ns do IO.println s!"{f}: {n} lines"
  AgenticDS.writeScatter "plot-m1v03.svg" "Files that pin the build"
    "file (1 toolchain, 2 lakefile, 3 manifest)" "lines"
    (ns.zipIdx.map fun (n, i) => ((i + 1).toFloat, n.toFloat))
    [] [] fs
