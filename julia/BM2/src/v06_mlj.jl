function make_machine(df)
    X, y = species_table(df), df.body_mass_g
    return machine(LinearRegressor(), X, y)
end

function show_params(mach)
    for (name, c) in named_params(fitted_params(mach))
        println(name, " ", round3(c))
    end
end

function matches_golden(mach)
    got = named_params(fitted_params(mach))
    return same_params(got, golden().species_model)
end

function main()
    mach = make_machine(load())
    fitted = isdefined(mach, :fitresult)
    println("before fit!: fitted = $fitted")
    fit!(mach; verbosity = 0)
    show_params(mach)
    verdict(!fitted && matches_golden(mach), "golden")
end
