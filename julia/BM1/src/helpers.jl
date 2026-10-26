# Plumbing for the scene files: paths, golden, verdict
# line, output capture. Nothing here is shown on camera.
const PKG = dirname(@__DIR__)
const DATA = joinpath(PKG, "data")
const ROOT = dirname(dirname(PKG))

golden() =
    JSON3.read(read(joinpath(DATA, "p1.json"), String))

function verdict(ok, words...)
    text = join(
        (
            "contract: b-m1",
            words...,
            ok ? "OK" : "FAILED",
        ),
        " ",
    )
    printstyled(text; color = ok ? 83 : 203)
    println()
    return ok
end

function capture(f)
    path = tempname()
    open(path, "w") do io
        Base.Multimedia.pushdisplay(TextDisplay(io))
        try
            redirect_stdio(f; stdout = io, stderr = io)
        finally
            Base.Multimedia.popdisplay()
        end
    end
    return read(path, String)
end

function capture_cmd(cmd)
    path = tempname()
    open(path, "w") do io
        run(
            pipeline(
                ignorestatus(cmd);
                stdout = io,
                stderr = io,
            ),
        )
    end
    return read(path, String)
end

function julia_cmd(dir, args...)
    exe = Cmd([first(Base.julia_cmd().exec)])
    cmd = `$exe --project=$dir $(args...)`
    return addenv(
        cmd,
        "JULIA_LOAD_PATH" => nothing,
        "JULIA_PROJECT" => nothing,
    )
end

# v03: run test code against a source file, keep the
# lines the video shows.
const SHOWN = ("Test Failed", "Expression", "Evaluated")

function shown(line)
    line = replace(line, r" +([0-9.]+m?s|Time)$" => "")
    keep =
        any(occursin(s, line) for s in SHOWN) ||
        startswith(line, "hello ") ||
        startswith(line, "Test Summary")
    return keep ? [strip(line)] : String[]
end

# A test set run inside another one reports to it, so
# give the scratch tests their own top level.
@static if isdefined(Test, :TESTSET_DEPTH)
    function fresh(f)
        return Base.ScopedValues.with(
            f,
            Test.TESTSET_DEPTH => 0,
            Test.CURRENT_TESTSET =>
                Test.FallbackTestSet(),
        )
    end
else
    function fresh(f)
        return task_local_storage(
            f,
            :__BASETESTNEXT__,
            Test.AbstractTestSet[],
        )
    end
end

function runtests(file, code)
    mod = Module(:Sandbox)
    Core.eval(mod, :(using Test))
    Base.include(mod, abspath(file))
    fails = Ref(0)
    out = capture() do
        try
            fresh() do
                include_string(mod, code, "runtests.jl")
            end
        catch err
            err =
                err isa LoadError ? err.error : err
            err isa Test.TestSetException ||
                rethrow(err)
            fails[] = err.fail + err.error
        end
    end
    lines = reduce(
        vcat,
        shown.(split(out, Char(10)));
        init = String[],
    )
    foreach(println, lines)
    return fails[]
end

# v05: the "Test Summary" rows of a Pkg.test log. A cell is
# read under its header word (numbers are right aligned), so
# a blank Pass or Fail cell is 0.
const SUITES = ("AgenticDS P1", "Aqua", "JET")

function cell(head, line, col)
    r = findfirst(col, head)
    isnothing(r) && return 0
    for m in eachmatch(r"[0-9]+", line)
        m.offset + length(m.match) - 1 == last(r) &&
            return parse(Int, m.match)
    end
    return 0
end

function test_rows(text)
    rows = NamedTuple[]
    head = ""
    for line in split(text, Char(10))
        startswith(line, "Test Summary:") &&
            (head = line)
        isempty(head) && continue
        for name in SUITES
            startswith(line, name * " ") || continue
            pass = cell(head, line, "Pass")
            total = cell(head, line, "Total")
            push!(rows, (; name, pass, total))
        end
    end
    return rows
end

# v08: load a (mutated) copy of AgenticDS.jl and list the
# golden checks it fails.
function load_module(text)
    mod = Module(:Mutant)
    include_string(mod, text, "AgenticDS.jl")
    return Base.invokelatest(
        getproperty,
        mod,
        :AgenticDS,
    )
end

failures(mod) = Base.invokelatest(golden_failures, mod)

function golden_failures(mod)
    bad = String[]
    csv = joinpath(DATA, "penguins.csv")
    clean = mod.na_policy(mod.read_penguins(csv))
    nrow(clean) == 342 ||
        push!(bad, "na_policy rows == 342")
    gold = golden().species
    sums = mod.summarise_by_species(clean)
    for row in eachrow(sums)
        g = gold[Symbol(row.species)]
        row.n == g.n ||
            push!(bad, "$(row.species) n == $(g.n)")
        for col in mod.NUMERIC_COLS
            for (stat, want) in (
                ("mean", g[col].mean),
                ("sd", g[col].sd),
            )
                got = row[Symbol(col, "_", stat)]
                isapprox(got, want; atol = 1e-9) ||
                    push!(
                        bad,
                        "$(row.species) $col $stat",
                    )
            end
        end
    end
    return bad
end

# v10: the "contract:" lines an example program prints.
function contracts(file)
    ads = joinpath(ROOT, "julia", "AgenticDS.jl")
    out = capture_cmd(julia_cmd(ads, abspath(file)))
    return filter(
        startswith("contract:"),
        split(out, Char(10)),
    )
end

# Shared by the v01 and v06 scenes.
gold_sp(name) = golden().species[Symbol(name)]
r2(x) = round(x; digits = 2)

function sha_ok(file)
    sums = read(joinpath(DATA, "SHA256SUMS"), String)
    return startswith(
        sums,
        bytes2hex(open(SHA.sha256, file)),
    )
end
