import AgenticDS.Examples.M1Data
/-! Recap: the two examples. -/

-- Recap: the two examples this module ships.
-- List them: ls examples
def m1v10 : IO Unit := do
  -- Real data: every complete penguin, bill length against body
  -- mass, with the species mean of each as a red mark. The recap
  -- shows the mean and variance the module is about.
  let rows ← AgenticDS.m1Rows
  let at' := fun (r : String × List ℚ) =>
    (AgenticDS.qf (r.2.getD 0 0), AgenticDS.qf (r.2.getD 3 0))
  let sps := ["Adelie", "Chinstrap", "Gentoo"]
  let marks := sps.map fun sp =>
    (AgenticDS.qf (AgenticDS.mean (AgenticDS.column rows sp 0)),
     AgenticDS.qf (AgenticDS.mean (AgenticDS.column rows sp 3)))
  for sp in sps do
    let m := AgenticDS.column rows sp 3
    IO.println s!"{sp}: n = {m.length}, mean = {AgenticDS.mean m} g"
  AgenticDS.writeScatter "plot-m1v10.svg" "Penguins: bill and mass"
    "bill length (mm)" "body mass (g)" (rows.map at') [] marks
    [s!"n = {rows.length} penguins", "red: species mean"]
