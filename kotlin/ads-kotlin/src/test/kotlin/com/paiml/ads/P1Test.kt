package com.paiml.ads

import com.fasterxml.jackson.databind.ObjectMapper
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.ByteArrayOutputStream
import java.io.PrintStream
import java.nio.file.Path
import kotlin.math.abs

private val root: Path = Path.of(System.getProperty("ads.root"))
private val csv: String =
    root.resolve(
        "datasets/penguins/penguins.csv",
    ).toString()
private const val TOL = 1e-9

class P1Test {
    private val golden =
        ObjectMapper().readTree(
            root.resolve("datasets/golden/p1.json").toFile(),
        )["species"]

    @Test
    fun readPenguinsKeepsAllRowsAndTypesNulls() {
        val rows = readPenguins(csv)
        assertEquals(344, rows.size)
        assertTrue(rows.any { it.billLengthMm == null })
        assertEquals("Adelie", rows.first().species)
        assertEquals(39.1, rows.first().billLengthMm)
    }

    @Test
    fun naPolicyDropsRowsMissingAMeasurement() {
        assertEquals(342, naPolicy(readPenguins(csv)).size)
    }

    @Test
    fun naPolicyDropsNaNMeasurement() {
        assertEquals(
            0,
            naPolicy(
                listOf(Penguin("A", Double.NaN, 2.0, 3.0, 4.0)),
            ).size,
        )
    }

    @Test
    fun naPolicyDropsEachMeasurementColumnAlone() {
        val full = Penguin("A", 1.0, 2.0, 3.0, 4.0)
        val broken =
            listOf(
                full.copy(billLengthMm = null),
                full.copy(billDepthMm = null),
                full.copy(flipperLengthMm = null),
                full.copy(bodyMassG = null),
            )
        assertEquals(0, naPolicy(broken).size)
    }

    @Test
    fun summaryMatchesGoldenWithinTolerance() {
        val summary =
            summariseBySpecies(naPolicy(readPenguins(csv)))
        assertEquals(
            golden.fieldNames().asSequence().toList(),
            summary.map {
                it.species
            },
        )
        for (s in summary) {
            assertEquals(
                MEASURES.toSet(),
                golden[s.species].fieldNames().asSequence()
                    .toSet() - "n",
            )
            val g = golden[s.species]
            assertEquals(g["n"].asInt(), s.n)
            for (col in MEASURES) {
                val gc = g[col]
                assertTrue(
                    abs(s.mean[col]!! - gc["mean"].asDouble()) <=
                        TOL,
                    "${s.species} $col mean",
                )
                assertTrue(
                    abs(s.sd[col]!! - gc["sd"].asDouble()) <= TOL,
                    "${s.species} $col sd",
                )
            }
        }
    }

    @Test
    fun sampleSdUsesNMinusOne() {
        val s =
            summariseBySpecies(
                listOf(
                    Penguin("A", 1.0, 1.0, 1.0, 1.0),
                    Penguin("A", 3.0, 3.0, 3.0, 3.0),
                ),
            ).single()
        assertEquals(
            Math.sqrt(2.0),
            s.sd["bill_length_mm"]!!,
            1e-12,
        )
    }

    @Test
    fun nullMeasurementIsSkippedByStats() {
        val rows =
            listOf(
                Penguin("A", 1.0, 1.0, 1.0, 1.0),
                Penguin("A", null, 1.0, 1.0, 1.0),
                Penguin("A", 3.0, 1.0, 1.0, 1.0),
            )
        assertEquals(
            2.0,
            summariseBySpecies(
                rows,
            ).single().mean["bill_length_mm"],
        )
    }

    @Test
    fun singleRowSpeciesHasNaNSd() {
        val s =
            summariseBySpecies(
                listOf(Penguin("A", 1.0, 1.0, 1.0, 1.0)),
            ).single()
        assertTrue(s.sd["body_mass_g"]!!.isNaN())
    }

    @Test
    fun noNaPolicyChangesCountsSoParityCanFail() {
        val withNa = summariseBySpecies(readPenguins(csv))
        assertFalse(
            withNa.map {
                it.n
            } ==
                golden.fields().asSequence().map {
                    it.value["n"].asInt()
                }.toList(),
        )
    }

    @Test
    fun profileJsonRoundTripsToGolden() {
        val json =
            ObjectMapper().readTree(
                profileJson(csv),
            )["species"]
        assertEquals(
            golden.fieldNames().asSequence().toList(),
            json.fieldNames().asSequence().toList(),
        )
        for (sp in golden.fieldNames()) {
            assertEquals(
                golden[sp]["n"].asInt(),
                json[sp]["n"].asInt(),
            )
            for (col in MEASURES) {
                for (stat in listOf("mean", "sd")) {
                    val want = golden[sp][col][stat].asDouble()
                    assertEquals(
                        want,
                        json[sp][col][stat].asDouble(),
                        TOL,
                        "$sp $col $stat",
                    )
                }
            }
        }
    }

    @Test
    fun ingestMainPrintsCounts() {
        assertTrue(
            captured {
                IngestMain.main(arrayOf(csv))
            }.contains("rows=344 kept=342"),
        )
    }

    @Test
    fun mainPrintsProfile() {
        val buf = ByteArrayOutputStream()
        val old = System.out
        System.setOut(PrintStream(buf))
        try {
            ProfileMain.main(arrayOf(csv))
        } finally {
            System.setOut(old)
        }
        assertTrue(buf.toString().contains("\"Chinstrap\""))
    }

    @Test
    fun readPenguinsRejectsMissingFile() {
        val missing =
            TempTrash.dir("ads").resolve("nope.csv").path
        assertTrue(runCatching { readPenguins(missing) }.isFailure)
    }
}

private fun captured(block: () -> Unit): String {
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
