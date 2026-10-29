import AgenticDS
import Lean.Data.Json

open AgenticDS Lean

def jnum (j : Json) : Option ℚ :=
  match j.getNum? with
  | .ok d => some ((d.mantissa : ℚ) / (10 ^ d.exponent : ℕ))
  | .error _ => none

def absLt (a b tol : ℚ) : Bool := (if a < b then b - a else a - b) < tol

def check (what : String) (ok : Bool) : IO Bool := do
  unless ok do IO.eprintln s!"FAIL {what}"
  pure ok

def main (args : List String) : IO UInt32 := do
  let root := args.headD "../.."
  let csv ← IO.FS.readFile s!"{root}/datasets/penguins/penguins.csv"
  let splitTxt ← IO.FS.readFile s!"{root}/datasets/fixtures/split.csv"
  let centTxt ← IO.FS.readFile s!"{root}/datasets/fixtures/centroids.csv"
  let golden ← IO.FS.readFile s!"{root}/datasets/golden/p3.json"
  let some g := (Json.parse golden).toOption | IO.eprintln "FAIL golden parse"; return 1
  let get (path : List String) : Option ℚ :=
    (path.foldl (fun j k => j.bind (fun j => (j.getObjVal? k).toOption)) (some g)).bind jnum
  let rows := completeRows csv
  let sets := (parseCsv splitTxt).drop 1 |>.filterMap (fun f => f[1]?)
  let labelled : List (Row × Bool) := (rows.zip sets).filterMap fun (r, s) =>
    (Species.ofString? r.1).map fun sp => ((r.2, sp), decide (s = "test"))
  let train := (labelled.filter (!·.2)).map Prod.fst
  let test := (labelled.filter (·.2)).map Prod.fst
  let tree := fitTree train
  let mut ok ← check "342 rows" (rows.length == 342 && sets.length == 342)
  ok := (← check "train n=257" (train.length == 257)) && ok
  -- the rediscovered rpart tree: flipper < 207.5 ? (bill_length < 43.35 ? Adelie : Chinstrap) : Gentoo
  let expected : Tree := .node 2 (415 / 2) (.node 0 (4335 / 100) (.leaf .adelie) (.leaf .chinstrap)) (.leaf .gentoo)
  ok := (← check "tree shape" (toString (repr tree) == toString (repr expected))) && ok
  let preds := test.map fun r => (r.2, tree.predict r.1)
  let conf := Species.all.map fun a => Species.all.map fun p => confusion preds a p
  let goldConf : List (List Nat) := [[37, 0, 0], [0, 16, 1], [0, 1, 30]]
  ok := (← check "confusion" (conf == goldConf)) && ok
  ok := (← check "confusion total" ((conf.map List.sum).sum == test.length)) && ok
  let acc : ℚ := ((Species.all.map fun s => confusion preds s s).sum : ℕ) / (test.length : ℚ)
  ok := (← check "accuracy" ((get ["accuracy"]).any (absLt acc · (1 / 1000000000000)))) && ok
  -- k-means on z-scored features == weighted squared distance with weights 1 / sampleVariance
  let pts := rows.map (·.2)
  let w := (List.range 4).map fun j => 1 / sampleVariance (pts.map (·.getD j 0))
  let cs0 := (parseCsv centTxt).drop 1 |>.map fun f => (f.drop 1).filterMap parseRat
  let (cl, cs) := lloyd w pts 100 [] cs0
  let obj := (pts.zip cl).map (fun (x, k) => wdist w x (cs.getD k [])) |>.sum
  let sizes := (List.range 3).map fun k => cl.count k
  ok := (← check "kmeans objective" ((get ["kmeans", "objective"]).any (absLt obj · (1 / 1000000)))) && ok
  ok := (← check "cluster sizes" (sizes == [133, 123, 86])) && ok
  if ok then IO.println "contract: ads-lean-p3-v1 OK"; return 0
  else return 1
