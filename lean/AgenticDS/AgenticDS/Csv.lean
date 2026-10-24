import Mathlib

namespace AgenticDS

/-- Parse an unsigned decimal such as `38.7` or `181` to an exact rational. -/
def parseRat (s : String) : Option ℚ :=
  match s.splitOn "." with
  | [i] => i.toNat?.map (fun n => (n : ℚ))
  | [i, f] =>
    match i.toNat?, f.toNat? with
    | some a, some b => some ((a : ℚ) + (b : ℚ) / (10 ^ f.length : ℕ))
    | _, _ => none
  | _ => none

/-- Split a CSV document into rows of fields (no quoting; the datasets have none). -/
def parseCsv (txt : String) : List (List String) :=
  (txt.splitOn "\n").filter (· ≠ "") |>.map (fun l => l.splitOn ",")

/-- One Palmer Penguins row with the four numeric measurements already parsed; `none` marks NA. -/
structure RawRow where
  species : String
  measures : List (Option ℚ)

/-- Read the four numeric columns (bill length, bill depth, flipper length, body mass). -/
def toRawRow (fields : List String) : Option RawRow :=
  match fields with
  | sp :: _ :: a :: b :: c :: d :: _ =>
    some ⟨sp, [a, b, c, d].map (fun s => if s = "NA" then none else parseRat s)⟩
  | _ => none

end AgenticDS
