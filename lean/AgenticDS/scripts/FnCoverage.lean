import Lean
open Lean

/-! # Function and refusal coverage over elaborated code (ads#130)

Reads the compiled `.olean` of every module, never the source text and
never an imported `Mathlib` environment. Starting from the entry points
(the `main` of every test and of every demo executable) it walks the
constants each definition uses, through the elaborated terms, so a name
inside a string or a comment, or a function nobody calls, is not
coverage. It prints:

* `DEF <module> <name> <how>`  one line per user-written definition of
  the library; `how` is the entry module that reaches it, or `UNTESTED`
* `SITE <module> <name> <kind>`  a refusal path: `none` when the result
  type is an `Option` and the term builds `none`, `throw` when the term
  throws an `IO.userError`
* `ENTRY <module>`  an entry point that was found

usage: `lean --run FnCoverage.lean <lib module>... -- <test module>...`
with the `.olean` search path given by `LEAN_PATH`. -/

structure CMod where
  name : String
  isTest : Bool
  consts : Std.HashMap Name ConstantInfo
  ranged : Std.HashSet Name
  deriving Inhabited

unsafe def rangedNames (entries : Array (Name × Array EnvExtensionEntry)) :
    Std.HashSet Name := Id.run do
  let mut s : Std.HashSet Name := {}
  for (k, es) in entries do
    if k.getString! == "declRangeExt" then
      for e in es do
        let p : Name × DeclarationRanges := unsafeCast e
        s := s.insert p.1
  return s

unsafe def load (m : String) (isTest : Bool) : IO CMod := do
  let fn ← findOLean m.toName
  let (md, _) ← readModuleData fn
  let mut cs : Std.HashMap Name ConstantInfo := {}
  for c in md.constants do cs := cs.insert c.name c
  return { name := m, isTest, consts := cs, ranged := rangedNames md.entries }

/-- Head constant of an application spine. -/
def headConst (e : Expr) : Option Name :=
  match e.getAppFn with
  | .const n _ => some n
  | _ => none

def resultType : Expr → Expr
  | .forallE _ _ b _ => resultType b
  | .mdata _ e => resultType e
  | e => e

/-- The result type is `Option _`, or `m (Option _)` for a monad `m`. -/
def returnsOption (t : Expr) : Bool :=
  let r := resultType t
  headConst r == some `Option ||
    (r.isApp && headConst r.appArg! == some `Option)

/-- Structure projections, instances and notation are generated or
boilerplate, not behaviour a test can target. -/
def stripLams : Expr -> Expr
  | .lam _ _ b _ => stripLams b
  | .mdata _ e => stripLams e
  | e => e

def isBoilerplate (n : Name) (ci : ConstantInfo) : Bool :=
  let isProj := match ci with
    | .defnInfo d => (stripLams d.value).isProj
    | _ => false
  let inst := n.components.any (·.toString.startsWith "inst")
  let hd := headConst (resultType ci.type)
  let isNota := hd == some `Lean.ParserDescr ||
    hd == some `Lean.TrailingParserDescr
  isProj || inst || isNota

def throwNames : List Name :=
  [`IO.userError, `MonadExcept.throw, `throwThe]

def used (ci : ConstantInfo) : Array Name :=
  match ci with
  | .defnInfo d => d.value.getUsedConstants
  | .opaqueInfo d => d.value.getUsedConstants
  | _ => #[]

unsafe def main (args : List String) : IO UInt32 := do
  let (libs, rest) := args.span (· != "--")
  let tests := rest.drop 1
  let lm ← libs.mapM (load · false)
  let tm ← tests.mapM (load · true)
  let mods : Array CMod := (lm ++ tm).toArray
  -- name -> modules that define it, library first
  let mut defs : Std.HashMap Name (List Nat) := {}
  for (m, i) in mods.zipIdx do
    for (n, _) in m.consts.toList do
      defs := defs.insert n (defs.getD n [] ++ [i])
  let resolve (from_ : Nat) (n : Name) : Option Nat :=
    if mods[from_]!.consts.contains n then some from_
    else
      ((defs.getD n []).filter fun i => !mods[i]!.isTest).head?
  -- entry points: every `main`
  let mut work : Array (Nat × Name × String) := #[]
  for (m, i) in mods.zipIdx do
    if m.consts.contains `main then
      IO.println s!"ENTRY {m.name}"
      work := work.push (i, `main, m.name)
  let mut how : Std.HashMap (Nat × Name) String := {}
  while h : work.size > 0 do
    let (i, n, e) := work.back
    work := work.pop
    if how.contains (i, n) then continue
    how := how.insert (i, n) e
    let some ci := mods[i]!.consts[n]? | continue
    let mut next := used ci
    let un := n ++ `_unsafe_rec
    if mods[i]!.consts.contains un then next := next.push un
    for u in next do
      if let some j := resolve i u then
        if !how.contains (j, u) then work := work.push (j, u, e)
  -- the library definitions and their refusal paths
  for (m, i) in mods.zipIdx do
    for (n, ci) in m.consts.toList do
      unless m.ranged.contains n do continue
      unless (match ci with | .defnInfo _ | .opaqueInfo _ => true | _ => false) do continue
      if n == `main || n.isInternal || isBoilerplate n ci then continue
      let tag := if m.isTest then "TDEF" else "DEF"
      IO.println s!"{tag} {m.name} {n} {(how.get? (i, n)).getD "UNTESTED"}"
      if m.isTest then continue
      let us := used ci
      if returnsOption ci.type && us.contains `Option.none then
        IO.println s!"SITE {m.name} {n} none"
      if us.any throwNames.contains then
        IO.println s!"SITE {m.name} {n} throw"
  return 0
