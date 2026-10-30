package com.paiml.ads

import com.fasterxml.jackson.databind.ObjectMapper
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import kotlin.math.abs

private val root: Path = Path.of(System.getProperty("ads.root"))
private const val HEAD =
    "fixed_acidity,volatile_acidity,citric_acid,residual_sugar," +
        "chlorides,free_sulfur_dioxide,total_sulfur_dioxide," +
        "density,pH,sulphates,alcohol,quality,color"

private fun wineCsv(
    vararg rows: String,
    color: String = "red",
): String {
    val f = TempTrash.dir("ads-wine").toPath().resolve("wine.csv")
    val body = rows.joinToString("\n") { "$it,$color" }
    Files.writeString(f, "$HEAD\n$body\n")
    return f.toString()
}

private fun tiny(
    quality: Double = 5.0,
    color: String = "red",
    x: Double = 1.0,
) = Wine(
    listOf(DoubleArray(FEATURES.size) { x }),
    doubleArrayOf(quality),
    listOf(color),
)

class P4Test {
    private val golden =
        ObjectMapper().readTree(
            root.resolve("datasets/golden/p4.json").toFile(),
        )
    private val wine = validate(readWine(RED, WHITE))
    private val split = splitWine(wine)
    private val score = scoreWine(split)

    @Test
    fun heldOutErrorMatchesTheROracle() {
        val rmse = golden["rmse"].asDouble()
        assertEquals(rmse, score.rmse, GOLDEN_TOL)
        val r2 = golden["r2"].asDouble()
        assertEquals(r2, score.r2, GOLDEN_TOL)
    }

    @Test
    fun rowCountsAndColourMeansMatchGolden() {
        assertEquals(golden["n_rows"].asInt(), wine.rows)
        assertEquals(golden["n_train"].asInt(), split.train.rows)
        assertEquals(golden["n_test"].asInt(), split.test.rows)
        val by = meanByColor(wine)
        val g = golden["mean_quality_by_color"]
        assertEquals(g["red"].asDouble(), by["red"]!!, GOLDEN_TOL)
        assertEquals(
            g["white"].asDouble(),
            by["white"]!!,
            GOLDEN_TOL,
        )
        assertTrue(matchesGolden(wine, split, score))
    }

    @Test
    fun constantsAgreeWithTheGoldenFile() {
        val g = golden["mean_quality_by_color"]
        assertEquals(golden["n_rows"].asInt(), GOLDEN_ROWS)
        assertEquals(golden["n_train"].asInt(), GOLDEN_TRAIN)
        assertEquals(golden["n_test"].asInt(), GOLDEN_TEST)
        assertEquals(
            golden["rmse"].asDouble(),
            GOLDEN_RMSE,
            GOLDEN_TOL,
        )
        assertEquals(golden["r2"].asDouble(), GOLDEN_R2, GOLDEN_TOL)
        assertEquals(g["red"].asDouble(), GOLDEN_RED, GOLDEN_TOL)
        assertEquals(
            g["white"].asDouble(),
            GOLDEN_WHITE,
            GOLDEN_TOL,
        )
    }

    @Test
    fun everyFifthRowIsTest() {
        assertEquals(wine.x[4].toList(), split.test.x[0].toList())
        assertEquals(1599, wine.color.count { it == "red" })
        assertEquals(wine.x[0].toList(), split.train.x[0].toList())
    }

    @Test
    fun fittingOnAllRowsLeaksAndFailsTheOracle() {
        val leaky = scoreOn(wine, split.test)
        assertTrue(abs(leaky.rmse - score.rmse) > 1e-4)
        assertFalse(matchesGolden(wine, split, leaky))
    }

    @Test
    fun anyGoldenMismatchFails() {
        assertFalse(matchesGolden(tiny(), split, score))
        assertFalse(matchesGolden(wine, Split(wine, wine), score))
        assertFalse(
            matchesGolden(wine, Split(split.train, wine), score),
        )
        val off = Score(score.rmse + 1e-3, score.r2)
        assertFalse(matchesGolden(wine, split, off))
        assertFalse(
            matchesGolden(wine, split, Score(score.rmse, 0.0)),
        )
    }

    @Test
    fun colourMeansMustMatchEach() {
        val shifted =
            Wine(
                wine.x,
                wine.quality
                    .map {
                        it + 1
                    }.toDoubleArray(),
                wine.color,
            )
        assertFalse(matchesGolden(shifted, split, score))
        val reds = wine.color.map { "red" }
        val oneColour = Wine(wine.x, wine.quality, reds)
        assertFalse(matchesGolden(oneColour, split, score))
    }

    @Test
    fun whiteMeanAloneCanFail() {
        val q = wine.quality.copyOf()
        val white =
            wine.color.indices.filter {
                wine.color[it] == "white"
            }
        white.forEach { q[it] += 1.0 }
        val w = Wine(wine.x, q, wine.color)
        assertFalse(matchesGolden(w, split, score))
    }

    @Test
    fun validateAcceptsTheDataAndRejectsDefects() {
        assertEquals(wine, validate(wine))
        assertThrows(IllegalStateException::class.java) {
            validate(tiny(x = Double.NaN))
        }
        assertThrows(IllegalStateException::class.java) {
            validate(tiny(quality = Double.NaN))
        }
        assertThrows(IllegalStateException::class.java) {
            validate(tiny(quality = 11.0))
        }
        assertThrows(IllegalStateException::class.java) {
            validate(tiny(quality = -1.0))
        }
        assertThrows(IllegalStateException::class.java) {
            validate(tiny(color = "rose"))
        }
    }

    @Test
    fun aMissingCellBecomesAGapAndIsRejected() {
        val ok = "7,0.7,0,1.9,0.076,11,34,0.9978,3.51,0.56,9.4,5"
        val gap = "7,,0,1.9,0.076,11,34,0.9978,3.51,0.56,9.4,5"
        val red = wineCsv(ok, gap)
        val white = wineCsv(ok, color = "white")
        val w = readWine(red, white)
        assertEquals(3, w.rows)
        assertThrows(IllegalStateException::class.java) {
            validate(w)
        }
    }

    @Test
    fun metricsOnAKnownVector() {
        val s =
            metrics(
                doubleArrayOf(1.0, 3.0),
                doubleArrayOf(2.0, 2.0),
            )
        assertEquals(1.0, s.rmse, 1e-12)
        assertEquals(0.0, s.r2, 1e-12)
    }

    @Test
    fun reportTtlMatchesTheCommittedArtifact() {
        val want =
            Files.readString(
                root.resolve("datasets/golden/p4-artifact.ttl"),
            )
        assertEquals(want, reportTtl(score.rmse, wine.rows))
    }

    @Test
    fun enginesAgreeAndDisagree() {
        val a = aggregateFrame(wine)
        val b = aggregatePlain(wine)
        assertEquals(setOf("red", "white"), a.keys)
        assertEquals(1599, a.getValue("red").second)
        assertEquals(4898, b.getValue("white").second)
        assertTrue(enginesAgree(a, b))
        val shifted =
            b.mapValues { (_, v) ->
                v.first + 1 to v.second
            }
        assertFalse(enginesAgree(a, shifted))
        val counts =
            b.mapValues { (_, v) ->
                v.first to v.second + 1
            }
        assertFalse(enginesAgree(a, counts))
        assertFalse(enginesAgree(a, b - "red"))
    }

    @Test
    fun benchTimesBothEnginesAndTheMedianIsTheMiddleRun() {
        val t = benchWine(wine)
        assertEquals(setOf("dataframe", "collections"), t.keys)
        assertTrue(t.values.all { it > 0 })
        var calls = 0
        medianSeconds(reps = 3) { calls++ }
        assertEquals(3, calls)
    }
}
