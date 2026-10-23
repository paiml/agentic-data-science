package com.paiml.ads

import org.jetbrains.kotlinx.dataframe.DataFrame
import org.jetbrains.kotlinx.dataframe.api.rows
import org.jetbrains.kotlinx.dataframe.io.readCsv

private const val FEATURE_LIST =
    "fixed_acidity,volatile_acidity,citric_acid,residual_sugar,chlorides,free_sulfur_dioxide," +
        "total_sulfur_dioxide,density,pH,sulphates,alcohol"

/** The eleven physico-chemical columns, in file order. */
val WINE_FEATURES: List<String> = FEATURE_LIST.split(",")

private const val QUALITY_MAX = 10
private const val TEST_EVERY = 5

/** One wine: its measurements, integer quality score and colour. */
data class WineRow(val x: DoubleArray, val quality: Int, val color: String)

data class WineSplit(val train: List<WineRow>, val test: List<WineRow>)

/** A quality that is not a whole number becomes -1, which [validateWine] refuses. */
private fun wholeQuality(v: Any?): Int {
    val d = (v as? Number)?.toDouble() ?: return -1
    return if (d == d.toInt().toDouble()) d.toInt() else -1
}

private fun readColor(path: String): List<WineRow> =
    DataFrame.readCsv(path).rows().map { r ->
        WineRow(
            DoubleArray(WINE_FEATURES.size) { j -> (r[WINE_FEATURES[j]] as? Number)?.toDouble() ?: Double.NaN },
            wholeQuality(r["quality"]),
            r["color"] as? String ?: "",
        )
    }

/** Read and bind the red and white tables (red rows first). A missing cell becomes NaN, caught by [validateWine]. */
fun readWine(
    red: String,
    white: String,
): List<WineRow> = readColor(red) + readColor(white)

/** Stop on a missing value, a quality outside 0..10 or an unknown colour. */
fun validateWine(rows: List<WineRow>): List<WineRow> {
    require(rows.none { r -> r.x.any { !it.isFinite() } }) { "wine data has missing or non-finite values" }
    require(rows.all { it.quality in 0..QUALITY_MAX }) { "quality outside 0..10" }
    require(rows.all { it.color == "red" || it.color == "white" }) { "unknown color" }
    return rows
}

/** Deterministic split: every fifth row (1-based) is a test row. */
fun splitWine(rows: List<WineRow>): WineSplit {
    val test = rows.filterIndexed { i, _ -> (i + 1) % TEST_EVERY == 0 }
    val train = rows.filterIndexed { i, _ -> (i + 1) % TEST_EVERY != 0 }
    return WineSplit(train, test)
}
