package com.paiml.ads

import com.fasterxml.jackson.databind.ObjectMapper
import org.jetbrains.kotlinx.dataframe.DataFrame
import org.jetbrains.kotlinx.dataframe.api.dropNulls
import org.jetbrains.kotlinx.dataframe.io.readCsv
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import kotlin.math.abs

private val root: Path = Path.of(System.getProperty("ads.root"))
private const val GOLDEN_TOL = 1e-6
private const val RESIDUAL_TOL = 1e-6

class OlsTest {
    private val golden =
        ObjectMapper().readTree(
            root.resolve("datasets/golden/p2.json").toFile(),
        )["ols"]
    private val df =
        DataFrame
            .readCsv(
                PENGUINS,
            ).dropNulls("flipper_length_mm", "body_mass_g")
    private val x = df.doubles("flipper_length_mm")
    private val y = df.doubles("body_mass_g")

    @Test
    fun dropNullsOnModelColumnsKeeps342Rows() {
        assertEquals(342, df.rowsCount())
    }

    @Test
    fun simpleFitMatchesGolden() {
        val fit = fitSimple(x, y)
        assertEquals(
            golden["intercept"].asDouble(),
            fit.intercept,
            GOLDEN_TOL,
        )
        assertEquals(
            golden["slope"].asDouble(),
            fit.slope,
            GOLDEN_TOL,
        )
    }

    @Test
    fun qrFitMatchesSimpleFit() {
        assertTrue(fitSimple(x, y).agrees(fitQr(x, y), TOL))
    }

    @Test
    fun agreesRejectsADifferentFit() {
        val fit = fitSimple(x, y)
        assertFalse(
            fit.agrees(fit.copy(slope = fit.slope + 1.0), TOL),
        )
        assertFalse(
            fit.agrees(
                fit.copy(intercept = fit.intercept + 1.0),
                TOL,
            ),
        )
    }

    @Test
    fun residualsSumToZero() {
        assertTrue(
            abs(residualSum(fitSimple(x, y), x, y)) < RESIDUAL_TOL,
        )
    }

    @Test
    fun residualSumCanFail() {
        val shifted =
            fitSimple(x, y).let {
                it.copy(intercept = it.intercept + 1.0)
            }
        assertEquals(
            x.size.toDouble(),
            -residualSum(shifted, x, y),
            RESIDUAL_TOL,
        )
    }

    @Test
    fun examplePrintsAGreenVerdictAndSavesThePlot() {
        main()
        assertTrue(Files.size(Path.of(PLOT)) > 0)
    }

    @Test
    fun verdictFailBranchIsRed() {
        assertTrue(verdict(false, "x").contains("FAIL"))
        assertTrue(verdict(true, "x").contains("PASS"))
    }

    @Test
    fun expectRowsRejectsAWrongCount() {
        expectRows(342, 342)
        assertThrows(IllegalStateException::class.java) {
            expectRows(344, 342)
        }
    }
}
