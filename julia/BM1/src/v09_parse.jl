num(x) = something(tryparse(Float64, x), missing)
const HEAD = "species,mass"
const BAD = ["Adelie,heavy", "Adelie,3800"]
const MSG = "bad number becomes missing, then dropped"
function read_mass(path)
    kinds = Dict(:mass => String)
    raw = CSV.read(path, DataFrame; types = kinds)
    return transform(raw, :mass => ByRow(num) => :mass)
end
function main()
    bad = joinpath(mktempdir(), "bad.csv")
    write(bad, join([HEAD; BAD], Char(10)))
    d = read_mass(bad)
    display(d)
    ok = eltype(d.mass) == Union{Missing,Float64}
    ok &=
        ismissing(d.mass[1]) &&
        nrow(dropmissing(d)) == 1
    verdict(ok, MSG)
end
