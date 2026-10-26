using JuliaFormatter
ok = format(ARGS[1]; verbose = false, overwrite = false)
println("format clean: ", ok)
ok || exit(1)
