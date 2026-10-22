package com.paiml.ads

import com.fasterxml.jackson.databind.ObjectMapper
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.ByteArrayOutputStream
import java.io.PrintStream
import java.nio.file.Files
import java.nio.file.Path
import kotlin.math.abs

private val root2: Path = Path.of(System.getProperty("ads.root"))
private val csv2: String = root2.resolve("datasets/penguins/penguins.csv").toString()
private val foldsPath: String = root2.resolve("datasets/fixtures/folds.csv").toString()
private const val TOL2 = 1e-8

class P2Test {
    private val golden = ObjectMapper().readTree(root2.resolve("datasets/golden/p2.json").toFile())
    private val rows = naPolicy(readPenguins(csv2))
    private val folds = readFolds(foldsPath)

    private fun near(
        expected: Double,
        actual: Double,
    ) = assertTrue(abs(expected - actual) <= TOL2, "expected $expected got $actual")

    @Test
    fun foldsAreOnePerCleanRowAndFixed() {
        assertEquals(rows.size, folds.size)
        assertEquals(setOf(1, 2, 3, 4, 5), folds.toSet())
        assertEquals(listOf(1, 2, 3), folds.take(3))
    }

    @Test
    fun olsMatchesGolden() {
        val m = fitOls(rows)
        near(golden["ols"]["intercept"].asDouble(), m.coef.getValue("(Intercept)"))
        near(golden["ols"]["slope"].asDouble(), m.coef.getValue("flipper_length_mm"))
    }

    @Test
    fun speciesModelMatchesGoldenAndNamesAllCoefficients() {
        val m = fitSpecies(rows)
        assertEquals(golden["species_model"].fieldNames().asSequence().toSet(), m.coef.keys)
        for ((k, v) in m.coef) near(golden["species_model"][k].asDouble(), v)
    }

    @Test
    fun metricsMatchGolden() {
        val y = rows.map { it.bodyMassG!! }
        for ((name, model) in listOf("ols" to fitOls(rows), "species" to fitSpecies(rows))) {
            val met = regressionMetrics(y, predict(model, rows))
            near(golden["metrics"][name]["rmse"].asDouble(), met.rmse)
            near(golden["metrics"][name]["r2"].asDouble(), met.r2)
        }
    }

    @Test
    fun cvRmseMatchesGolden() {
        near(golden["cv_rmse"]["ols"].asDouble(), cvRmse(rows, folds, false))
        near(golden["cv_rmse"]["species"].asDouble(), cvRmse(rows, folds, true))
    }

    @Test
    fun cvIsOutOfFoldAndCanFail() {
        val y = rows.map { it.bodyMassG!! }
        val inSample = regressionMetrics(y, predict(fitOls(rows), rows)).rmse
        assertTrue(cvRmse(rows, folds, false) > inSample)
        assertThrows(IllegalArgumentException::class.java) { cvRmse(rows, List(rows.size) { 1 }, false) }
    }

    @Test
    fun cvEqualsHandRolledPerFoldOracle() {
        val pred = DoubleArray(rows.size)
        for (k in 1..5) {
            val m = fitOls(rows.filterIndexed { i, _ -> folds[i] != k })
            val idx = rows.indices.filter { folds[it] == k }
            predict(m, idx.map { rows[it] }).forEachIndexed { j, v -> pred[idx[j]] = v }
        }
        val oracle = regressionMetrics(rows.map { it.bodyMassG!! }, pred.toList()).rmse
        assertEquals(oracle, cvRmse(rows, folds, false), 1e-12)
    }

    @Test
    fun toleranceRefusesAShiftJustAboveIt() {
        assertThrows(AssertionError::class.java) { near(1.0, 1.0 + 2 * TOL2) }
    }

    @Test
    fun foldCountMismatchIsRefused() {
        assertThrows(IllegalArgumentException::class.java) { cvRmse(rows, folds.drop(1), false) }
    }

    @Test
    fun exactLineIsRecoveredWithPerfectFit() {
        val pts = (1..5).map { Penguin("A", 0.0, 0.0, it.toDouble(), 3.0 + 2.0 * it) }
        val m = fitOls(pts)
        assertEquals(3.0, m.coef.getValue("(Intercept)"), 1e-9)
        assertEquals(2.0, m.coef.getValue("flipper_length_mm"), 1e-9)
        val met = regressionMetrics(pts.map { it.bodyMassG!! }, predict(m, pts))
        assertEquals(0.0, met.rmse, 1e-9)
        assertEquals(1.0, met.r2, 1e-9)
    }

    @Test
    fun singularDesignIsRefused() {
        val pts = listOf(Penguin("A", 0.0, 0.0, 2.0, 1.0), Penguin("A", 0.0, 0.0, 2.0, 3.0))
        assertThrows(IllegalArgumentException::class.java) { fitOls(pts) }
    }

    @Test
    fun p2JsonHasGoldenKeysAndValues() {
        val out = ObjectMapper().readTree(p2Json(csv2, foldsPath))
        assertEquals(golden.fieldNames().asSequence().toList(), out.fieldNames().asSequence().toList())
        near(golden["cv_rmse"]["species"].asDouble(), out["cv_rmse"]["species"].asDouble())
        near(golden["ols"]["slope"].asDouble(), out["ols"]["slope"].asDouble())
        near(golden["metrics"]["species"]["r2"].asDouble(), out["metrics"]["species"]["r2"].asDouble())
        assertEquals(golden["species_model"].size(), out["species_model"].size())
    }

    @Test
    fun mainPrintsContractLine() {
        val buf = ByteArrayOutputStream()
        val old = System.out
        System.setOut(PrintStream(buf))
        try {
            RegressMain.main(arrayOf(csv2, foldsPath))
        } finally {
            System.setOut(old)
        }
        assertTrue(buf.toString().lines().any { it == "contract: ads-kotlin-p2 OK" })
    }

    @Test
    fun contractRefusesLeakageAndWorseSpeciesModel() {
        RegressMain.checkContract(1.0, 2.0, 1.5)
        assertThrows(IllegalStateException::class.java) { RegressMain.checkContract(2.0, 1.0, 0.5) }
        assertThrows(IllegalStateException::class.java) { RegressMain.checkContract(1.0, 2.0, 2.5) }
    }

    @Test
    fun readFoldsParsesFile() {
        val f = Files.createTempFile("folds", ".csv")
        Files.writeString(f, "row,fold\n1,2\n2,1\n")
        try {
            assertEquals(listOf(2, 1), readFolds(f.toString()))
        } finally {
            Files.delete(f)
        }
    }
}
