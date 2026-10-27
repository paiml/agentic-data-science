package com.paiml.ads

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.ByteArrayOutputStream
import java.io.PrintStream
import com.paiml.ads.m4v01.main as wineMain
import com.paiml.ads.m4v02.main as benchMain

private fun stdout(block: () -> Unit): String {
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

/** The number printed after [label], read back from [out]. */
private fun printed(
    out: String,
    label: String,
) = Regex("$label[^:]*:\\s*([0-9.]+)")
    .find(out)!!.groupValues[1].toDouble()

class M4ExamplesTest {
    @Test
    fun wineExampleMatchesTheGolden() {
        val out = stdout { wineMain() }
        val rmse = printed(out, "rmse")
        assertEquals(GOLDEN_RMSE, rmse, GOLDEN_TOL)
        val r2 = printed(out, "r2")
        assertEquals(GOLDEN_R2, r2, GOLDEN_TOL)
        assertTrue("P4 vs golden PASS" in out, out)
    }

    @Test
    fun benchChecksAgreementBeforeTiming() {
        val out = stdout { benchMain() }
        assertTrue("1599 rows" in out, out)
        assertTrue("4898 rows" in out, out)
        val at = out.indexOf("agree")
        assertTrue(at in 0 until out.indexOf("timed"))
        assertTrue("P4 bench PASS" in out, out)
    }

    @Test
    fun benchPrintsNoClockNumber() {
        val out = stdout { benchMain() }
        val clock = Regex("""\d\s*(ms|us|ns|sec|s)\b|elapsed""")
        assertFalse(clock.containsMatchIn(out.lowercase()), out)
    }
}
