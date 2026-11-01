package lab

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

// Expected values: datasets/golden/p1.json (342 = 151+68+123; Adelie body_mass_g mean) and p2.json (ols).
private val CSV: String = System.getProperty("lab.csv")

class LabTest {
    @Test
    fun lab_t1_clean_rows() = assertEquals(342, cleanRows(CSV))

    @Test
    fun lab_t2_adelie_mean_mass() = assertEquals(3700.66225165563, adelieMeanMass(CSV), 1e-6)

    @Test
    fun lab_t3_mass_on_flipper() {
        val fit = massOnFlipper(CSV)
        assertEquals(-5780.83135807716, fit.intercept, 1e-6)
        assertEquals(49.6855664061006, fit.slope, 1e-6)
    }
}
