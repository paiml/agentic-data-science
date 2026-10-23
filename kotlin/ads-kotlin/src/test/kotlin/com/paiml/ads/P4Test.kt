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

private val root4: Path = Path.of(System.getProperty("ads.root"))
private val red: String = root4.resolve("datasets/wine-quality/winequality-red.csv").toString()
private val white: String = root4.resolve("datasets/wine-quality/winequality-white.csv").toString()
private const val TOL4 = 1e-6

class P4Test {
    private val golden = ObjectMapper().readTree(root4.resolve("datasets/golden/p4.json").toFile())
    private val rows = readWine(red, white)

    private fun near(
        expected: Double,
        actual: Double,
        tol: Double = TOL4,
    ) = assertTrue(abs(expected - actual) <= tol, "expected $expected got $actual")

    private fun capture(block: () -> Unit): String {
        val buf = ByteArrayOutputStream()
        val old = System.out
        System.setOut(PrintStream(buf))
        try {
            block()
        } finally {
            System.setOut(old)
        }
        return buf.toString()
    }

    @Test
    fun readBindsBothColoursWithTypedColumns() {
        assertEquals(6497, rows.size)
        assertEquals(1599, rows.count { it.color == "red" })
        assertEquals(4898, rows.count { it.color == "white" })
        assertEquals(11, rows[0].x.size)
        assertEquals(5, rows[0].quality)
    }

    @Test
    fun validateAcceptsTheDataAndRejectsEachDefect() {
        assertEquals(rows, validateWine(rows))
        val nan = rows.toMutableList().also { it[0] = it[0].copy(x = it[0].x.copyOf().also { x -> x[3] = Double.NaN }) }
        assertThrows(IllegalArgumentException::class.java) { validateWine(nan) }
        val badQ = rows.toMutableList().also { it[0] = it[0].copy(quality = 11) }
        assertThrows(IllegalArgumentException::class.java) { validateWine(badQ) }
        val negQ = rows.toMutableList().also { it[0] = it[0].copy(quality = -1) }
        assertThrows(IllegalArgumentException::class.java) { validateWine(negQ) }
        val badC = rows.toMutableList().also { it[0] = it[0].copy(color = "rose") }
        assertThrows(IllegalArgumentException::class.java) { validateWine(badC) }
    }

    @Test
    fun defectiveCsvCellsSurfaceAsValidationErrors() {
        val head = WINE_FEATURES.joinToString(",") + ",quality,color\n"
        val ok = "7.4,0.7,0,1.9,0.076,11,34,0.9978,3.51,0.56,9.4"
        val cases =
            mapOf(
                "blank cell" to "7.4,,0,1.9,0.076,11,34,0.9978,3.51,0.56,9.4,5,red",
                "NA token" to "7.4,NA,0,1.9,0.076,11,34,0.9978,3.51,0.56,9.4,5,red",
                "fractional quality" to "$ok,5.5,red",
                "missing colour" to "$ok,5,",
                "infinity" to "7.4,Infinity,0,1.9,0.076,11,34,0.9978,3.51,0.56,9.4,5,red",
            )
        for ((name, line) in cases) {
            val f = Files.createTempFile("wine", ".csv").toFile().also { it.deleteOnExit() }
            f.writeText(head + line + "\n")
            assertThrows(IllegalArgumentException::class.java, { validateWine(readWine(f.path, f.path)) }, name)
        }
    }

    @Test
    fun splitSendsEveryFifthRowToTest() {
        val s = splitWine(rows)
        assertEquals(1299, s.test.size)
        assertEquals(5198, s.train.size)
        assertEquals(rows[4], s.test[0])
        assertEquals(rows[0], s.train[0])
        assertEquals(rows[5], s.train[4])
    }

    @Test
    fun pipelineMatchesGolden() {
        val res = pipelineWine(rows)
        assertEquals(golden["n_rows"].asInt(), res.nRows)
        assertEquals(golden["n_train"].asInt(), res.nTrain)
        assertEquals(golden["n_test"].asInt(), res.nTest)
        near(golden["rmse"].asDouble(), res.rmse)
        near(golden["r2"].asDouble(), res.r2)
        near(golden["mean_quality_by_color"]["red"].asDouble(), res.meanByColor.getValue("red"), 1e-12)
        near(golden["mean_quality_by_color"]["white"].asDouble(), res.meanByColor.getValue("white"), 1e-12)
    }

    @Test
    fun heldOutRmseDiffersFromTrainingFitOnAllRows() {
        val s = splitWine(rows)
        val honest = fitWine(s.train)
        val leaky = fitWine(rows)
        val y = s.test.map { it.quality.toDouble() }
        val a = regressionMetrics(y, predictWine(honest, s.test)).rmse
        val b = regressionMetrics(y, predictWine(leaky, s.test)).rmse
        assertTrue(abs(a - b) > 1e-4, "leaky fit must differ: $a vs $b")
    }

    @Test
    fun fitRecoversAKnownLinearModel() {
        var seed = 12345L
        val synth =
            List(60) { i ->
                val x =
                    DoubleArray(11) {
                        seed = (seed * 1103515245L + 12345L) % 2147483648L
                        seed / 2147483648.0
                    }
                WineRow(x, 0, if (i % 2 == 0) "red" else "white")
            }
        val y = synth.map { 2.0 + 0.5 * it.x[0] + 3.0 * (if (it.color == "white") 1.0 else 0.0) }
        val m = fitLinear(synth, y)
        val pred = predictLinear(m, synth)
        for (i in synth.indices) near(y[i], pred[i], 1e-6)
    }

    @Test
    fun singularDesignIsRefused() {
        val same = List(20) { WineRow(DoubleArray(11) { 1.0 }, 5, "red") }
        assertThrows(IllegalArgumentException::class.java) { fitLinear(same, List(20) { 5.0 }) }
    }

    @Test
    fun enginesAgreeOnEveryColour() {
        val a = aggregateFrame(rows)
        val b = aggregateMap(rows)
        assertEquals(listOf("red", "white"), a.map { it.color })
        assertEquals(a.map { it.color }, b.map { it.color })
        assertEquals(a.map { it.n }, b.map { it.n })
        for (i in a.indices) near(a[i].meanQuality, b[i].meanQuality, 1e-12)
        assertEquals(listOf(1599, 4898), a.map { it.n })
    }

    @Test
    fun benchTimesBothEnginesWithAnInjectedClock() {
        var t = 0L
        val out =
            benchWine(rows, 3) {
                t += 5
                t
            }
        assertEquals(listOf("dataframe", "collections"), out.map { it.engine })
        assertTrue(out.all { it.seconds >= 0.0 })
        near(5.0e-9, out[0].seconds, 1e-12)
        assertThrows(IllegalArgumentException::class.java) { benchWine(rows, 0) { 0L } }
    }

    @Test
    fun medianPicksTheMiddle() {
        near(2.0, median(listOf(3.0, 1.0, 2.0)), 0.0)
        near(2.5, median(listOf(4.0, 1.0, 2.0, 3.0)), 0.0)
    }

    @Test
    fun jsonAndTurtleMatchTheCommittedArtifacts() {
        val res = pipelineWine(rows)
        val got = ObjectMapper().readTree(wineJson(res))
        for (k in listOf("n_rows", "n_train", "n_test")) assertEquals(golden[k], got[k])
        for (k in listOf("rmse", "r2")) near(golden[k].asDouble(), got[k].asDouble())
        for (k in listOf("red", "white")) {
            near(golden["mean_quality_by_color"][k].asDouble(), got["mean_quality_by_color"][k].asDouble(), 1e-12)
        }
        assertEquals(listOf("red", "white"), got["mean_quality_by_color"].fieldNames().asSequence().toList())
        val ttl = root4.resolve("datasets/golden/p4-artifact.ttl").toFile().readText().trim()
        assertEquals(ttl, reportTtl(res).trim())
    }

    @Test
    fun contractAcceptsGoodAndRefusesBad() {
        WineMain.checkContract(pipelineWine(rows))
        val res = pipelineWine(rows)
        assertThrows(IllegalStateException::class.java) { WineMain.checkContract(res.copy(r2 = -0.1)) }
        assertThrows(IllegalStateException::class.java) { WineMain.checkContract(res.copy(nTrain = res.nTrain + 1)) }
    }

    @Test
    fun mainsPrintContractAndTable() {
        val out = capture { WineMain.main(arrayOf(red, white)) }
        assertTrue(out.contains("contract: ads-kotlin-p4 OK"))
        val bench = capture { BenchMain.main(arrayOf(red, white, "2")) }
        assertTrue(bench.contains("dataframe") && bench.contains("collections"))
        assertTrue(bench.contains("contract: ads-kotlin-p4-bench OK"))
    }
}
