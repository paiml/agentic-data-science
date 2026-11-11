using Coverage
c = process_folder(joinpath(ARGS[1], "src"))
covered, total = get_summary(c)
println("coverage: ", covered, "/", total)
for f in c
    for (i, n) in enumerate(f.coverage)
        n === 0 && println("UNCOVERED ", f.filename, ":", i)
    end
end
total > 0 && covered == total || (println("coverage FAIL: measured nothing or gaps"); exit(1))
