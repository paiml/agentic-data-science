package com.paiml.ads

import com.paiml.ads.anscombe.Quartet
import com.paiml.ads.anscombe.holds
import com.paiml.ads.anscombe.main
import com.paiml.ads.anscombe.parityText
import com.paiml.ads.anscombe.readQuartets
import com.paiml.ads.anscombe.report
import com.paiml.ads.anscombe.run
import com.paiml.ads.anscombe.summarise
import com.paiml.ads.anscombe.writePlot
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.PrintStream

private val CSV =
    File(
        System.getProperty("ads.root"),
        "data/anscombe/anscombe.csv",
    ).path

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

class AnscombeTest {
    @Test
    fun fourSetsOfElevenShareTheirNumbers() {
        val sums = readQuartets(CSV).map(::summarise)
        assertEquals(
            listOf("I", "II", "III", "IV"),
            sums.map { it.name },
        )
        assertTrue(sums.all { it.n == 11 })
        sums.forEach {
            assertEquals(9.0, it.meanX, 1e-9)
            assertEquals(7.5, it.meanY, 1e-2)
            assertEquals(0.5, it.slope, 1e-2)
            assertEquals(3.0, it.intercept, 1e-2)
            assertEquals(0.67, it.r2, 1e-2)
            assertEquals(0.82, it.r, 1e-2)
        }
        assertTrue(holds(sums))
    }

    @Test
    fun reportEndsOnTheContractLine() {
        val out = report(readQuartets(CSV).map(::summarise))
        assertEquals(5, out.lines().filter { it.isNotEmpty() }.size)
        assertTrue(
            out.trimEnd().endsWith(
                "sets identical to 2 decimals OK",
            ),
        )
        assertTrue(
            "set I: n=11 mean_x=9.00 mean_y=7.50 " +
                "slope=0.50 intercept=3.00 r=0.82" in
                out,
        )
    }

    @Test
    fun aShiftedSetBreaksTheContract() {
        val qs = readQuartets(CSV)
        val bad =
            qs.mapIndexed { i, q ->
                if (i ==
                    2
                ) {
                    Quartet(q.name, q.x, q.y.map { it + 1.0 })
                } else {
                    q
                }
            }
        val sums = bad.map(::summarise)
        assertFalse(holds(sums))
        assertTrue(report(sums).trimEnd().endsWith("FAILED"))
        assertFalse(holds(sums.drop(1)))
        assertFalse(holds(sums.map { it.copy(n = 10) }))
    }

    @Test
    fun runIsDeterministicAndWritesAFixedSizeSvg(
        @TempDir dir: File,
    ) {
        val a = File(dir, "a").also { it.mkdirs() }
        val b = File(dir, "b").also { it.mkdirs() }
        val outA =
            captured { assertEquals(0, run(arrayOf(CSV, a.path))) }
        val outB =
            captured { assertEquals(0, run(arrayOf(CSV, b.path))) }
        assertEquals(outA, outB)
        val svgA = File(a, "plot.svg").readText()
        assertEquals(svgA, File(b, "plot.svg").readText())
        assertEquals(
            parityText(readQuartets(CSV).map(::summarise)),
            File(a, "stdout.txt").readText(),
        )
        assertTrue(
            File(a, "stdout.txt").readText().lines().first() ==
                "set I: n=11 mean_x=9.00 mean_y=7.50 " +
                "slope=0.50 intercept=3.00 r=0.82",
        )
        assertTrue("<svg" in svgA)
        assertTrue("1200" in svgA && "900" in svgA)
    }

    @Test
    fun mainFailsLoudlyOnABrokenQuartet(
        @TempDir dir: File,
    ) {
        val csv = File(dir, "bad.csv")
        csv.writeText(
            File(
                CSV,
            ).readText().replace("IV,19,12.50", "IV,19,13.50"),
        )
        captured {
            assertThrows(IllegalStateException::class.java) {
                main(arrayOf(csv.path, dir.path))
            }
        }
        captured { main(arrayOf(CSV, dir.path)) }
        val sums = readQuartets(CSV).map(::summarise)
        File(dir, "plot2").mkdirs()
        writePlot(readQuartets(CSV), sums, File(dir, "plot2").path)
        assertTrue(File(dir, "plot2/plot.svg").length() > 0)
    }
}
