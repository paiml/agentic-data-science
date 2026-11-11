function intercept_design(df)
    x = df.flipper_length_mm
    return [ones(length(x)) x]
end

function species_dummies(df)
    chin = Float64.(df.species .== "Chinstrap")
    gentoo = Float64.(df.species .== "Gentoo")
    return hcat(df.flipper_length_mm, chin, gentoo)
end

baseline(df) = count(==("Adelie"), df.species)

function main()
    df = load()
    X, Z = intercept_design(df), species_dummies(df)
    r, c = size(X)
    println("rows $(nrow(df)), X is $r x $c")
    println("X[1:3,:] = ", X[1:3, :])
    nc, ng = Int.(sum(Z[:, 2:3]; dims = 1))
    adelie = baseline(df)
    println("dummy sums: $nc, $ng; Adelie $adelie")
    ok = (r, c) == (342, 2) && (nc, ng) == (68, 123)
    verdict(ok && adelie == 151, "design matrices")
end
