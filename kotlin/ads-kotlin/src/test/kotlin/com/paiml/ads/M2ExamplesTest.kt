package com.paiml.ads

import com.fasterxml.jackson.databind.ObjectMapper
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.ByteArrayOutputStream
import java.io.PrintStream
import java.nio.file.Files
import java.nio.file.Path

private const val GOLDEN_KEY = "ads.golden"
private const val EXACT = 1e-12

private val goldenPath: Path =
    Path.of(System.getProperty("ads.root"))
        .resolve("datasets/golden/p2.json")

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

class M2ExamplesTest {
    init {
        System.setProperty(GOLDEN_KEY, goldenPath.toString())
    }

    @Test
    fun goldenOlsReadsTheOlsBlock() {
        val ols =
            ObjectMapper().readTree(
                goldenPath.toFile(),
            )["ols"]
        val fit = goldenOls()
        assertEquals(
            ols["intercept"].asDouble(),
            fit.intercept,
            EXACT,
        )
        assertEquals(ols["slope"].asDouble(), fit.slope, EXACT)
    }

    @Test
    fun m2v01PrintsGreenVerdicts() {
        val out = capture { com.paiml.ads.m2v01.main() }
        assertTrue(out.contains("Residual sum PASS"))
        assertTrue(out.trim().endsWith("Golden P2 PASS"))
        assertFalse(out.contains("FAIL"))
    }

    @Test
    fun m2v01FailsOnAShiftedGolden() {
        val shifted =
            TempTrash.dir("ads-p2").toPath()
                .resolve("p2.json")
        Files.writeString(
            shifted,
            goldenPath.toFile().readText()
                .replace("-5780.8", "-5781.8"),
        )
        System.setProperty(GOLDEN_KEY, shifted.toString())
        try {
            val out = capture { com.paiml.ads.m2v01.main() }
            assertTrue(out.contains("Golden P2 FAIL"))
            assertTrue(out.contains("Residual sum PASS"))
        } finally {
            System.setProperty(GOLDEN_KEY, goldenPath.toString())
            Files.delete(shifted)
        }
    }
}
