package lab

import com.paiml.ads.Fit
import com.paiml.ads.fitSimple
import com.paiml.ads.naPolicy
import com.paiml.ads.readPenguins
import com.paiml.ads.summariseBySpecies

/** Task 1: rows left after the course NA policy. */
fun cleanRows(path: String): Int = naPolicy(readPenguins(path)).size

/** Task 2: the Adelie mean body mass (g) after the NA policy. */
fun adelieMeanMass(path: String): Double =
    summariseBySpecies(naPolicy(readPenguins(path))).first { it.species == "Adelie" }.mean.getValue("body_mass_g")

/** Task 3: OLS of body mass on flipper length over the cleaned rows. */
fun massOnFlipper(path: String): Fit {
    val rows = naPolicy(readPenguins(path))
    return fitSimple(
        rows.map { it.flipperLengthMm!! }.toDoubleArray(),
        rows.map { it.bodyMassG!! }.toDoubleArray(),
    )
}
