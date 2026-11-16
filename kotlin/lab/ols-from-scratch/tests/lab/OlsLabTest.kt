package lab

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.File
import kotlin.math.abs

// Provable contract: the from-scratch fit reproduces the course's golden OLS
// (datasets/golden/p2.json, key "ols") on the penguins data to 1e-6.
private const val GOLDEN_INTERCEPT = -5780.83135807716
private const val GOLDEN_SLOPE = 49.6855664061006
private const val GOLDEN_TOL = 1e-6
private const val RESIDUAL_TOL = 1e-6
private const val ROWS = 342

private fun penguins(): Pair<DoubleArray, DoubleArray> {
    val lines = File(System.getProperty("lab.csv")).readLines()
    val head = lines.first().split(",")
    val fx = head.indexOf("flipper_length_mm")
    val my = head.indexOf("body_mass_g")
    val rows =
        lines
            .drop(1)
            .map { it.split(",") }
            .filter { it[fx] != "NA" && it[my] != "NA" && it[fx].isNotBlank() && it[my].isNotBlank() }
    return rows.map { it[fx].toDouble() }.toDoubleArray() to
        rows.map { it[my].toDouble() }.toDoubleArray()
}

class OlsLabTest {
    @Test
    fun exactLineIsRecovered() {
        val x = doubleArrayOf(0.0, 1.0, 2.0, 3.0)
        val y = doubleArrayOf(1.0, 3.0, 5.0, 7.0)
        val fit = fitOls(x, y)
        assertEquals(1.0, fit.intercept, 1e-12)
        assertEquals(2.0, fit.slope, 1e-12)
    }

    @Test
    fun penguinsKeep342Rows() {
        assertEquals(ROWS, penguins().first.size)
    }

    @Test
    fun penguinFitMatchesGolden() {
        val (x, y) = penguins()
        val fit = fitOls(x, y)
        assertEquals(GOLDEN_INTERCEPT, fit.intercept, GOLDEN_TOL)
        assertEquals(GOLDEN_SLOPE, fit.slope, GOLDEN_TOL)
    }

    @Test
    fun residualsOfAnOlsFitSumToZero() {
        val (x, y) = penguins()
        val fit = fitOls(x, y)
        assertTrue(abs(residualSum(fit, x, y)) < RESIDUAL_TOL) { "residual sum ${residualSum(fit, x, y)}" }
    }

    @Test
    fun residualSumOfAWrongLineIsNotZero() {
        val x = doubleArrayOf(0.0, 1.0, 2.0)
        val y = doubleArrayOf(0.0, 1.0, 2.0)
        assertEquals(3.0, residualSum(Fit(intercept = -1.0, slope = 1.0), x, y), 1e-12)
    }

    @Test
    fun lengthMismatchIsRefused() {
        assertThrows(IllegalArgumentException::class.java) {
            fitOls(doubleArrayOf(1.0, 2.0, 3.0), doubleArrayOf(1.0, 2.0))
        }
    }

    @Test
    fun constantXIsRefused() {
        assertThrows(IllegalArgumentException::class.java) {
            fitOls(doubleArrayOf(2.0, 2.0, 2.0), doubleArrayOf(1.0, 2.0, 3.0))
        }
    }

    @Test
    fun singlePointIsRefused() {
        assertThrows(IllegalArgumentException::class.java) {
            fitOls(doubleArrayOf(1.0), doubleArrayOf(1.0))
        }
    }
}
