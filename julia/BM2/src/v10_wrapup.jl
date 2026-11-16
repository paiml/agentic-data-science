function quiet(f)
    path, io = mktemp()
    redirect_stdout(f, io)
    close(io)
    return read(path, String)
end

function keep(text)
    lines = readlines(IOBuffer(text))
    return filter(startswith("contract:"), lines)
end

good(lines) =
    length(lines) == 2 && all(endswith("OK"), lines)

function main()
    a = keep(quiet(V09.ols_example))
    b = keep(quiet(V09.cv_example))
    foreach(println, [a; b])
    verdict(good([a; b]), "wrap-up")
end
