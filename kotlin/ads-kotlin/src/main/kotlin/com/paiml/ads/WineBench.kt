package com.paiml.ads

import org.jetbrains.kotlinx.dataframe.api.count
import org.jetbrains.kotlinx.dataframe.api.dataFrameOf
import org.jetbrains.kotlinx.dataframe.api.groupBy
import org.jetbrains.kotlinx.dataframe.api.mean
import org.jetbrains.kotlinx.dataframe.api.rows
import org.jetbrains.kotlinx.dataframe.api.sortBy

private const val NANOS = 1e9

/** Mean quality and row count of one colour. */
data class ColorAgg(val color: String, val meanQuality: Double, val n: Int)

data class BenchRow(val engine: String, val seconds: Double)

/** Grouped mean with a Kotlin DataFrame. */
fun aggregateFrame(rows: List<WineRow>): List<ColorAgg> {
    val g = dataFrameOf("color" to rows.map { it.color }, "quality" to rows.map { it.quality }).groupBy("color")
    val means = g.mean("quality").sortBy("color").rows().toList()
    val counts = g.count().sortBy("color").rows().toList()
    return means.indices.map {
        val mean = (means[it]["quality"] as Number).toDouble()
        ColorAgg(means[it]["color"] as String, mean, (counts[it]["count"] as Number).toInt())
    }
}

/** Grouped mean with plain collections. */
fun aggregateMap(rows: List<WineRow>): List<ColorAgg> =
    rows.groupBy { it.color }.toSortedMap().map { (c, v) ->
        ColorAgg(c, v.sumOf { it.quality } / v.size.toDouble(), v.size)
    }

fun median(xs: List<Double>): Double {
    val s = xs.sorted()
    return if (s.size % 2 == 1) s[s.size / 2] else (s[s.size / 2 - 1] + s[s.size / 2]) / 2.0
}

private fun timeOne(
    reps: Int,
    nanoTime: () -> Long,
    f: () -> Unit,
): Double =
    median(
        List(reps) {
            val t0 = nanoTime()
            f()
            (nanoTime() - t0) / NANOS
        },
    )

/** Median wall time of the two engines; [nanoTime] is injectable so the timing path is testable. */
fun benchWine(
    rows: List<WineRow>,
    reps: Int,
    nanoTime: () -> Long = System::nanoTime,
): List<BenchRow> {
    require(reps >= 1) { "reps must be at least 1" }
    return listOf(
        BenchRow("dataframe", timeOne(reps, nanoTime) { aggregateFrame(rows) }),
        BenchRow("collections", timeOne(reps, nanoTime) { aggregateMap(rows) }),
    )
}
