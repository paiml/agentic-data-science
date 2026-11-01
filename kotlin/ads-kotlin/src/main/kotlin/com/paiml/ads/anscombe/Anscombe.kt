package com.paiml.ads.anscombe

import org.jetbrains.kotlinx.dataframe.api.column
import org.jetbrains.kotlinx.dataframe.api.dataFrameOf
import org.jetbrains.kotlinx.kandy.dsl.plot
import org.jetbrains.kotlinx.kandy.letsplot.export.save
import org.jetbrains.kotlinx.kandy.letsplot.feature.layout
import org.jetbrains.kotlinx.kandy.letsplot.layers.line
import org.jetbrains.kotlinx.kandy.letsplot.layers.points
import org.jetbrains.kotlinx.kandy.letsplot.multiplot.facet.facetWrap
import java.io.File
import java.util.Locale

private const val PLOT_WIDTH = 1200
private const val PLOT_HEIGHT = 900
private const val POINT_SIZE = 6.0
private const val DECIMALS = 2
private const val SETS = 4
private const val ROWS_PER_SET = 11

/** One of the four sets of the quartet. */
data class Quartet(
    val name: String,
    val x: List<Double>,
    val y: List<Double>,
)

/** Descriptive numbers of one set, all from closed forms. */
data class Summary(
    val name: String,
    val n: Int,
    val meanX: Double,
    val meanY: Double,
    val slope: Double,
    val intercept: Double,
    val r2: Double,
    val r: Double,
)

/** Read `dataset,x,y` rows into quartets, in the order the sets first appear. */
fun readQuartets(path: String): List<Quartet> =
    File(path)
        .readLines()
        .drop(1)
        .map { it.split(',') }
        .groupBy(
            { it[0] },
            { it[1].toDouble() to it[2].toDouble() },
        ).map { (name, pts) ->
            Quartet(
                name,
                pts.map { it.first },
                pts.map { it.second },
            )
        }

/** n, means, least-squares line and R squared of one set. */
fun summarise(q: Quartet): Summary {
    val n = q.x.size
    val mx = q.x.sum() / n
    val my = q.y.sum() / n
    val sxx = q.x.sumOf { (it - mx) * (it - mx) }
    val syy = q.y.sumOf { (it - my) * (it - my) }
    val sxy = q.x.indices.sumOf { (q.x[it] - mx) * (q.y[it] - my) }
    val slope = sxy / sxx
    return Summary(
        q.name,
        n,
        mx,
        my,
        slope,
        my - slope * mx,
        sxy * sxy / (sxx * syy),
        sxy / Math.sqrt(sxx * syy),
    )
}

private fun fmt(v: Double): String =
    String.format(Locale.ROOT, "%.${DECIMALS}f", v)

/** The parity text: one line per set, byte-equal across languages. */
fun parityText(sums: List<Summary>): String =
    sums.joinToString("") {
        "set ${it.name}: n=${it.n} " +
            "mean_x=${fmt(it.meanX)} mean_y=${fmt(it.meanY)} " +
            "slope=${fmt(it.slope)} " +
            "intercept=${fmt(it.intercept)} r=${fmt(it.r)}\n"
    }

/** The console report: the parity text, then the contract line. */
fun report(sums: List<Summary>): String {
    val ok = holds(sums)
    val status = if (ok) "OK" else "FAILED"
    val verdict =
        "contract: ads-kotlin-anscombe-v1 $SETS sets " +
            "identical to $DECIMALS decimals $status"
    return parityText(sums) + verdict + "\n"
}

/** The quartet's point: four different clouds, the same numbers to [DECIMALS] decimals. */
fun holds(sums: List<Summary>): Boolean =
    sums.size == SETS &&
        sums.all { it.n == ROWS_PER_SET } &&
        listOf<(Summary) -> Double>(
            { it.meanX },
            { it.meanY },
            { it.slope },
            { it.intercept },
            { it.r2 },
            { it.r },
        ).all { f -> sums.map { fmt(f(it)) }.toSet().size == 1 }

/** Scatter and fitted line, one panel per set, at a fixed size, written as SVG to [dir]/plot.svg. */
fun writePlot(
    quartets: List<Quartet>,
    sums: List<Summary>,
    dir: String,
) {
    val names = quartets.flatMap { q -> q.x.map { q.name } }
    val xs = quartets.flatMap { it.x }
    val ys = quartets.flatMap { it.y }
    val fit =
        quartets.flatMapIndexed { i, q ->
            q.x.map {
                sums[i].intercept +
                    sums[i].slope * it
            }
        }
    val df =
        dataFrameOf(
            "dataset" to names,
            "x" to xs,
            "y" to ys,
            "fit" to fit,
        )
    val chart =
        df.plot {
            points {
                x("x")
                y("y")
                size = POINT_SIZE
            }
            line {
                x("x")
                y("fit")
            }
            facetWrap(nCol = 2) { facet(column<String>("dataset")) }
            layout {
                title = "Anscombe's quartet"
                size = PLOT_WIDTH to PLOT_HEIGHT
            }
        }
    chart.save("plot.svg", path = dir)
    val svg = File(dir, "plot.svg")
    svg.writeText(stableIds(svg.readText()))
}

/**
 * Print the report to stdout and write plot.svg into `args[1]`.
 * `args[0]` is the CSV. Returns 1 if the contract fails.
 */
fun run(args: Array<String>): Int {
    val quartets = readQuartets(args[0])
    val sums = quartets.map(::summarise)
    print(report(sums))
    File(args[1]).mkdirs()
    File(args[1], "stdout.txt").writeText(parityText(sums))
    writePlot(quartets, sums, args[1])
    return if (holds(sums)) 0 else 1
}

fun main(args: Array<String>) {
    check(run(args) == 0) { "anscombe contract FAILED" }
}

private val RANDOM_ID = Regex("""id="([A-Za-z][A-Za-z0-9]{6})"""")

/**
 * lets-plot stamps a fresh random 7-character id on every element it declares, so two runs of the same
 * chart differ byte-for-byte. Each declared id is renamed to `ads-N` in order of first appearance
 * (every reference follows, `#id` and `url(#id)` alike), which makes plot.svg reproducible.
 */
internal fun stableIds(svg: String): String {
    val ids =
        RANDOM_ID
            .findAll(svg)
            .map {
                it.groupValues[1]
            }.distinct()
            .toList()
    return ids.foldIndexed(
        svg,
    ) { i, acc, id -> acc.replace(id, "ads-$i") }
}
