package com.paiml.ads

/** Fewest points, axis strokes and tick labels a plot must draw. */
const val MIN_POINTS = 2
const val MIN_AXES = 4
const val MIN_TICKS = 8

/** What a plot SVG draws: points, axis and grid strokes, ticks. */
data class PlotParts(
    val points: Int,
    val axes: Int,
    val ticks: Int,
)

private fun count(
    tag: String,
    svg: String,
) = Regex("<$tag[ >/]").findAll(svg).count()

/**
 * lets-plot draws each legend key as a circle at cx=cy=10.5 inside
 * its own box (measured on the fit plot). A key is not data.
 */
private const val LEGEND_KEY = "cx=\"10.5\" cy=\"10.5\""

private fun dataPoints(svg: String) =
    Regex("<circle[ >/][^>]*>")
        .findAll(svg)
        .count { LEGEND_KEY !in it.value }

/** Count the parts of [svg]; text that is no SVG counts zero. */
fun measurePlot(svg: String) =
    PlotParts(
        points = dataPoints(svg),
        axes = count("line", svg) + count("path", svg),
        ticks = count("text", svg),
    )

private fun refusal(
    have: Int,
    min: Int,
    what: String,
) = "fewer than $min $what ($have)".takeIf { have < min }

/** One line per missing part; an empty list is a real plot. */
fun plotRefusals(svg: String): List<String> {
    val p = measurePlot(svg)
    return listOfNotNull(
        "empty or missing svg".takeIf { svg.isBlank() },
        refusal(p.points, MIN_POINTS, "points"),
        refusal(p.axes, MIN_AXES, "axis or grid strokes"),
        refusal(p.ticks, MIN_TICKS, "tick labels"),
    )
}
