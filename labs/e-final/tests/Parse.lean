import Lean
open Lean Parser

/-- Grader-owned command classifier. Parses Mean.lean with Lean's own command parser in an Init-only environment
    (sound here because syntax/macro/notation/elab are refused by the token layer) and allowlists command KINDS.
    Nothing is elaborated or executed: the parser only builds syntax trees. -/
def okTop : List Name := [`Lean.Parser.Command.namespace, `Lean.Parser.Command.section, `Lean.Parser.Command.end,
  `Lean.Parser.Command.open, `Lean.Parser.Command.variable]
def okDecl : List Name := [`Lean.Parser.Command.definition, `Lean.Parser.Command.theorem, `Lean.Parser.Command.example]

def refuse (msg : String) : IO UInt32 := do
  IO.println s!"parse: REFUSED {msg}"
  return 1

unsafe def main (args : List String) : IO UInt32 := do
  let some path := args.head? | return (← refuse "no file")
  let src ← IO.FS.readFile path
  initSearchPath (← findSysroot)
  let ictx := mkInputContext src path
  let (hdr, ps, msgs) ← parseHeader ictx
  if hdr.raw[1].getNumArgs != 0 then return (← refuse "an import line is not allowed")
  enableInitializersExecution  -- runs only Init's own initializers: the grader imports nothing of the learner's
  let env ← importModules #[{ module := `Init }] {} (loadExts := true)
  let pmctx : ParserModuleContext := { env, options := {}, currNamespace := .anonymous, openDecls := [] }
  let mut ps := ps
  let mut msgs := msgs
  let mut n := 0
  repeat
    let (stx, ps', msgs') := parseCommand ictx pmctx ps msgs
    ps := ps'; msgs := msgs'
    if msgs.hasErrors then return (← refuse s!"parse error: {← msgs.toList.mapM (·.toString)}")
    if stx.isOfKind `Lean.Parser.Command.eoi then break
    let pos := ictx.fileMap.toPosition (stx.getPos?.getD 0)
    let at_ := s!"{pos.line}:{pos.column}"
    let k := stx.getKind
    if k == `Lean.Parser.Command.declaration then
      -- declModifiers: only an (optional) doc comment; no attributes, visibility, noncomputable, unsafe, partial
      let mods := stx[0]
      for i in [1:mods.getNumArgs] do
        unless mods[i].getNumArgs == 0 do return (← refuse s!"declaration modifier at {at_} (only a doc comment is allowed)")
      let dk := stx[1].getKind
      unless okDecl.contains dk do return (← refuse s!"command kind {dk} at {at_}")
    else if k == `Lean.Parser.Command.open then
      if (stx.find? (·.isOfKind `Lean.Parser.Command.openScoped)).isSome || (stx.find? (·.isOfKind `Lean.Parser.Command.openSimple)).isNone then
        return (← refuse s!"only plain `open Name` is allowed, at {at_}")
    else unless okTop.contains k do return (← refuse s!"command kind {k} at {at_}")
    n := n + 1
  if n == 0 then return (← refuse "no commands")
  IO.println s!"parse: OK ({n} commands, all allowlisted kinds)"
  return 0
