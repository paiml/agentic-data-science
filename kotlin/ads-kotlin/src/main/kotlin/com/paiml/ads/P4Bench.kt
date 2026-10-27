package com.paiml.ads

import org.jetbrains.kotlinx.dataframe.api.aggregate
import org.jetbrains.kotlinx.dataframe.api.count
import org.jetbrains.kotlinx.dataframe.api.dataFrameOf
import org.jetbrains.kotlinx.dataframe.api.groupBy
import org.jetbrains.kotlinx.dataframe.api.mean
import org.jetbrains.kotlinx.dataframe.api.rows
import kotlin.math.abs

const val BENCH_REPS = 20
private const val NANOS = 1e9

/** Mean quality and row count per colour, DataFrame engine. */
fun aggregateFrame(wine: Wine): Map<String, Pair<Double, Int>> {
    val df =
        dataFrameOf(
            "color" to wine.color,
            "quality" to wine.quality.toList(),
        )
    val g =
        df.groupBy("color").aggregate {
            mean("quality") into "mean_quality"
            count() into "n"
        }
    return g.rows().associate {
        val m = it["mean_quality"] as Double
        (it["color"] as String) to (m to it["n"] as Int)
    }
}

/** The same aggregate over plain Kotlin collections. */
fun aggregatePlain(wine: Wine): Map<String, Pair<Double, Int>> =
    meanByColor(wine).mapValues { (c, m) ->
        m to wine.color.count { it == c }
    }

/** True when two engines agree on every colour within [tol]. */
fun enginesAgree(
    a: Map<String, Pair<Double, Int>>,
    b: Map<String, Pair<Double, Int>>,
    tol: Double = 1e-12,
): Boolean =
    a.keys == b.keys &&
        a.all { (k, v) ->
            val w = b.getValue(k)
            abs(v.first - w.first) <= tol && v.second == w.second
        }

/** Median seconds of [reps] runs of [f]. */
fun medianSeconds(
    reps: Int = BENCH_REPS,
    f: () -> Unit,
): Double {
    val secs =
        List(reps) {
            val t0 = System.nanoTime()
            f()
            (System.nanoTime() - t0) / NANOS
        }.sorted()
    return secs[reps / 2]
}

/** Median seconds per engine (callers check agreement first). */
fun benchWine(wine: Wine): Map<String, Double> =
    mapOf(
        "dataframe" to medianSeconds { aggregateFrame(wine) },
        "collections" to medianSeconds { aggregatePlain(wine) },
    )
