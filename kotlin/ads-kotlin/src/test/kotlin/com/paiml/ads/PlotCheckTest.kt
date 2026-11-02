package com.paiml.ads

import com.paiml.ads.anscombe.readQuartets
import com.paiml.ads.anscombe.summarise
import com.paiml.ads.anscombe.writePlot
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import java.io.File

private const val ANSCOMBE_POINTS = 44

/** The legend draws one circle per species, so the fit plot holds one circle per penguin plus three. */
private const val SPECIES_KEYS = 3
private val CSV =
    File(
        System.getProperty("ads.root"),
        "data/anscombe/anscombe.csv",
    ).path

private fun anscombeSvg(dir: File): String {
    val quartets = readQuartets(CSV)
    writePlot(quartets, quartets.map(::summarise), dir.path)
    return File(dir, "plot.svg").readText()
}

private fun fitSvg(dir: File): String {
    val df = loadClean()
    plotFit(
        df,
        fitSimple(df.doubles(FLIPPER), df.doubles(MASS)),
        "fit.svg",
        dir.path,
    )
    return File(dir, "fit.svg").readText()
}

private fun without(
    svg: String,
    tag: String,
) = svg.replace(Regex("<$tag[ >/][^>]*>(</$tag>)?"), "")

/** ads-kotlin-plot-v1: a plot SVG draws points, axes and tick labels, and the check goes red when one is deleted. */
class PlotCheckTest {
    @Test
    fun anscombeIsARealPlot(
        @TempDir dir: File,
    ) {
        val svg = anscombeSvg(dir)
        assertEquals(emptyList<String>(), plotRefusals(svg))
        assertEquals(ANSCOMBE_POINTS, measurePlot(svg).points)
    }

    @Test
    fun theFitPlotIsARealPlotWithOnePointPerPenguin(
        @TempDir dir: File,
    ) {
        val svg = fitSvg(dir)
        assertEquals(emptyList<String>(), plotRefusals(svg))
        assertEquals(ROWS + SPECIES_KEYS, measurePlot(svg).points)
    }

    @Test
    fun deletingThePointsGoesRed(
        @TempDir dir: File,
    ) {
        listOf(
            anscombeSvg(
                File(dir, "a").also {
                    it.mkdirs()
                },
            ),
            fitSvg(File(dir, "b").also { it.mkdirs() }),
        ).forEach {
            val refusals = plotRefusals(without(it, "circle"))
            assertEquals(1, refusals.size)
            assertTrue("points" in refusals.single())
        }
    }

    @Test
    fun deletingTheAxesOrTheTicksGoesRed(
        @TempDir dir: File,
    ) {
        val svg = anscombeSvg(dir)
        val noAxes =
            plotRefusals(without(without(svg, "line"), "path"))
        assertTrue(noAxes.any { "axis" in it })
        val noTicks = plotRefusals(without(svg, "text"))
        assertTrue(noTicks.any { "tick" in it })
    }

    @Test
    fun anEmptyOrNonSvgFileGoesRed() {
        assertTrue(plotRefusals("").any { "empty" in it })
        assertEquals(3, plotRefusals("not an svg").size)
        assertEquals(PlotParts(0, 0, 0), measurePlot("not an svg"))
    }
}
