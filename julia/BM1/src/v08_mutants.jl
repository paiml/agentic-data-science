const NA = "dropmissing(df, NUMERIC_COLS)"
const POP = "(x -> std(x; corrected = false)) =>"
const MUTANTS =
    [NA => "dropmissing(df)", "std =>" => POP]
function kill(src, (from, to))
    println("mutation: ", from, " -> ", to)
    bad =
        failures(load_module(replace(src, from => to)))
    foreach(b -> println("FAIL ", b), first(bad, 2))
    println("failed: ", length(bad))
    return !isempty(bad)
end
function main()
    src = read(something(pathof(AgenticDS)), String)
    ok = all([kill(src, m) for m in MUTANTS])
    verdict(ok, "NA policy and sd mutants are caught")
end
