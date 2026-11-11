const SETS = ("penguins", "wine-quality")
function sums_ok(dir)
    root = joinpath(ROOT, "datasets", dir)
    for line in eachline(joinpath(root, "SHA256SUMS"))
        hash, file = split(line)
        path = joinpath(root, file)
        bytes2hex(open(sha256, path)) == hash ||
            return false
    end
    return filesize(joinpath(root, "LICENSE")) > 0
end
function shapes_ok(file)
    text = read(file, String)
    pat = r"sh:path (ads:[A-Za-z]+)"
    need = [
        m[1] for
        m in eachmatch(pat, read(SHAPES, String))
    ]
    return all(p -> contains(text, "  $p "), need)
end
function main()
    data = all(sums_ok, SETS)
    println("datasets ", data ? "OK" : "FAILED")
    shapes = shapes_ok(R_TTL)
    println("shapes ", shapes ? "OK" : "FAILED")
    verdict(data && shapes, "datasets and shapes green")
end
