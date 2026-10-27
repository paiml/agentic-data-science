package com.paiml.ads

import org.apache.commons.math3.stat.regression.OLSMultipleLinearRegression
import org.jetbrains.kotlinx.dataframe.AnyFrame
import org.jetbrains.kotlinx.dataframe.DataFrame
import org.jetbrains.kotlinx.dataframe.io.readCsv
import kotlin.math.sqrt

/** Wine tables: the system property lets the tests redirect. */
private val WINE_DIR: String =
    System.getProperty("ads.root", ".") + "/datasets/wine-quality"
val RED: String = "$WINE_DIR/winequality-red.csv"
val WHITE: String = "$WINE_DIR/winequality-white.csv"

/** Golden (datasets/golden/p4.json, produced by the R oracle). */
const val GOLDEN_ROWS = 6497
const val GOLDEN_TRAIN = 5198
const val GOLDEN_TEST = 1299
const val GOLDEN_RMSE = 0.760251606190075
const val GOLDEN_R2 = 0.25985449136456
const val GOLDEN_RED = 5.63602251407129
const val GOLDEN_WHITE = 5.87790935075541
const val GOLDEN_TOL = 1e-6

private const val EVERY = 5
private const val MAX_QUALITY = 10.0
private val COLORS = setOf("red", "white")

/** The 11 physico-chemical predictors, in file order. */
val FEATURES: List<String> =
    listOf(
        "fixed_acidity",
        "volatile_acidity",
        "citric_acid",
        "residual_sugar",
        "chlorides",
        "free_sulfur_dioxide",
        "total_sulfur_dioxide",
        "density",
        "pH",
        "sulphates",
        "alcohol",
    )

/** Rows of predictors, quality and colour; NaN marks a gap. */
class Wine(
    val x: List<DoubleArray>,
    val quality: DoubleArray,
    val color: List<String>,
) {
    val rows: Int get() = quality.size

    /** The rows at [idx], in that order. */
    fun pick(idx: List<Int>) =
        Wine(
            idx.map { x[it] },
            idx.map { quality[it] }.toDoubleArray(),
            idx.map { color[it] },
        )
}

data class Split(
    val train: Wine,
    val test: Wine,
)

data class Score(
    val rmse: Double,
    val r2: Double,
)

private fun AnyFrame.column(name: String): List<Double> =
    this[name].values().map {
        (it as Number?)?.toDouble() ?: Double.NaN
    }

/** Read one colour table (predictors, quality, colour). */
private fun readOne(path: String): Wine {
    val df = DataFrame.readCsv(path)
    val cols = FEATURES.map { df.column(it) }
    return Wine(
        (0 until df.rowsCount()).map { i ->
            cols.map { it[i] }.toDoubleArray()
        },
        df.column("quality").toDoubleArray(),
        df["color"].values().map { it.toString() },
    )
}

/** Red rows first, then white, as in the R oracle. */
fun readWine(
    red: String,
    white: String,
): Wine {
    val (r, w) = readOne(red) to readOne(white)
    return Wine(
        r.x + w.x,
        r.quality + w.quality,
        r.color + w.color,
    )
}

/** Stop on a gap, a bad quality or an unknown colour. */
fun validate(wine: Wine): Wine {
    val gap =
        wine.x.any { r -> r.any { it.isNaN() } } ||
            wine.quality.any { it.isNaN() }
    check(!gap) { "wine data has missing values" }
    check(wine.quality.all { it in 0.0..MAX_QUALITY }) {
        "quality outside 0..10"
    }
    check(COLORS.containsAll(wine.color)) {
        "unknown color"
    }
    return wine
}

/** Every fifth row (5, 10, ...) is a test row. */
fun splitWine(wine: Wine): Split {
    val idx = 0 until wine.rows
    val (test, train) =
        idx.partition { (it + 1) % EVERY == 0 }
    return Split(wine.pick(train), wine.pick(test))
}

/** Predictors plus a white flag, as lm(quality ~ .). */
private fun design(wine: Wine): Array<DoubleArray> =
    Array(wine.rows) { i ->
        val w = if (wine.color[i] == "white") 1.0 else 0.0
        wine.x[i] + w
    }

/** RMSE and R squared of [pred] against [y]. */
fun metrics(
    y: DoubleArray,
    pred: DoubleArray,
): Score {
    val sse =
        y.indices.sumOf {
            (y[it] - pred[it]) * (y[it] - pred[it])
        }
    val mean = y.average()
    val sst = y.sumOf { (it - mean) * (it - mean) }
    return Score(sqrt(sse / y.size), 1 - sse / sst)
}

/** Fit on [fit] rows, score on [eval] rows. */
fun scoreOn(
    fit: Wine,
    eval: Wine,
): Score {
    val reg = OLSMultipleLinearRegression()
    reg.newSampleData(fit.quality, design(fit))
    val b = reg.estimateRegressionParameters()
    val pred =
        design(eval).map { r ->
            b[0] + r.indices.sumOf { b[it + 1] * r[it] }
        }
    return metrics(eval.quality, pred.toDoubleArray())
}

/** The held-out score: fit on train rows only. */
fun scoreWine(split: Split): Score =
    scoreOn(split.train, split.test)
