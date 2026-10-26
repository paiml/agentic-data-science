package com.paiml.ads

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.PrintStream
import com.paiml.ads.m1v01.main as ingestExample
import com.paiml.ads.m1v02.main as profileExample

private const val GOLDEN_KEYS = 27

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

private fun summary() =
    summariseBySpecies(
        naPolicy(readPenguins(PENGUINS)),
    )

class M1ExamplesTest {
    @Test
    fun ingestExampleKeeps342Of344() {
        val out = captured { ingestExample() }
        assertTrue(out.contains("344"))
        assertTrue(out.contains("VERDICT: ingest 344 -> 342 PASS"))
    }

    @Test
    fun profileExampleMatchesTheGolden() {
        val out = captured { profileExample() }
        assertTrue(out.contains("Chinstrap"))
        assertTrue(
            out.contains("VERDICT: profile matches R golden PASS"),
        )
    }

    @Test
    fun goldenGapIsTinyForTheRealProfile() {
        assertTrue(withinTol(goldenGap(summary(), GOLDEN_P1)))
    }

    @Test
    fun goldenGapCatchesAShiftedMean() {
        val shifted =
            summary().map { s ->
                s.copy(mean = s.mean.mapValues { it.value + 1.0 })
            }
        assertFalse(withinTol(goldenGap(shifted, GOLDEN_P1)))
    }

    @Test
    fun goldenGapCatchesTheMissingNaPolicy() {
        val raw = summariseBySpecies(readPenguins(PENGUINS))
        assertFalse(withinTol(goldenGap(raw, GOLDEN_P1)))
    }

    @Test
    fun countsHoldRejectsEachWrongCount() {
        val rows = readPenguins(PENGUINS)
        val kept = naPolicy(rows)
        assertTrue(countsHold(rows, kept))
        assertFalse(countsHold(rows, rows))
        assertFalse(countsHold(kept, kept))
    }

    @Test
    fun goldenGapIsInfiniteWhenASpeciesIsMissing() {
        assertEquals(
            Double.POSITIVE_INFINITY,
            goldenGap(summary().drop(1), GOLDEN_P1),
        )
    }

    @Test
    fun goldenValuesFlattenSpeciesColumnStat() {
        val g = goldenValues(GOLDEN_P1)
        assertEquals(GOLDEN_KEYS, g.size)
        assertEquals(151.0, g.getValue("species/Adelie/n"))
        assertTrue(g.containsKey("species/Gentoo/body_mass_g/sd"))
    }

    @Test
    fun goldenValuesReadNestedNumbers() {
        val f = File(TempTrash.dir("ads-gold"), "gold.json")
        f.writeText("{\n  \"a\": {\n    \"x\": 1.5\n  }\n}\n")
        assertEquals(mapOf("a/x" to 1.5), goldenValues(f))
        assertFalse(goldenValues(f).isEmpty())
    }

    @Test
    fun showSpeciesPrintsNAndMeans() {
        val out = captured { showSpecies(summary().first()) }
        assertTrue(out.contains("n=151"))
    }
}
