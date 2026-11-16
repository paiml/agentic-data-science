package lab

import com.paiml.ads.Fit

/** Task 1: rows left after the course NA policy (readPenguins, then naPolicy). */
fun cleanRows(path: String): Int = TODO("readPenguins + naPolicy, then size")

/** Task 2: the Adelie mean body mass (g) after the NA policy (summariseBySpecies). */
fun adelieMeanMass(path: String): Double = TODO("summariseBySpecies(...) for Adelie, mean[\"body_mass_g\"]")

/** Task 3: OLS of body mass on flipper length over the cleaned rows (fitSimple). */
fun massOnFlipper(path: String): Fit = TODO("fitSimple(flipper, mass)")
