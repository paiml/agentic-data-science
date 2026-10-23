package com.paiml.ads

import java.util.Locale
import kotlin.math.sqrt

/** Intercept, the eleven feature slopes, then the white-colour dummy (red is the baseline, as in R). */
data class LinearModel(val coef: List<Double>)

/** Everything the pipeline reports; timings are never part of it. */
data class WineResult(
    val nRows: Int,
    val nTrain: Int,
    val nTest: Int,
    val rmse: Double,
    val r2: Double,
    val meanByColor: Map<String, Double>,
)

private fun design(r: WineRow): List<Double> = r.x.toList() + (if (r.color == "white") 1.0 else 0.0)

private fun columnStats(cols: List<List<Double>>): List<Pair<Double, Double>> =
    cols.map { c ->
        val m = c.sum() / c.size
        m to sqrt(c.sumOf { (it - m) * (it - m) } / c.size)
    }

/**
 * Least squares of quality on the features and colour. Columns are centred and scaled before the normal equations
 * (density sits near 1 while sugar reaches 65), then mapped back to raw units.
 */
fun fitLinear(
    rows: List<WineRow>,
    y: List<Double>,
): LinearModel {
    val d = rows.map(::design)
    val stats = columnStats(d[0].indices.map { j -> d.map { it[j] } })
    require(stats.all { it.second > 0.0 }) { "singular design matrix: constant column" }
    val z = d.map { row -> listOf(1.0) + row.indices.map { j -> (row[j] - stats[j].first) / stats[j].second } }
    val b = solveNormal(z, y)
    val slopes = stats.indices.map { j -> b[j + 1] / stats[j].second }
    val intercept = b[0] - slopes.indices.sumOf { slopes[it] * stats[it].first }
    return LinearModel(listOf(intercept) + slopes)
}

fun predictLinear(
    model: LinearModel,
    rows: List<WineRow>,
): List<Double> = rows.map { r -> model.coef[0] + design(r).indices.sumOf { model.coef[it + 1] * design(r)[it] } }

fun fitWine(rows: List<WineRow>): LinearModel = fitLinear(rows, rows.map { it.quality.toDouble() })

fun predictWine(
    model: LinearModel,
    rows: List<WineRow>,
): List<Double> = predictLinear(model, rows)

/** Validate, split, fit on the training rows only, score on the test rows. */
fun pipelineWine(all: List<WineRow>): WineResult {
    val rows = validateWine(all)
    val s = splitWine(rows)
    val m = regressionMetrics(s.test.map { it.quality.toDouble() }, predictWine(fitWine(s.train), s.test))
    val byColor =
        rows.groupBy { it.color }.toSortedMap()
            .mapValues { (_, v) -> v.sumOf { it.quality } / v.size.toDouble() }
    return WineResult(rows.size, s.train.size, s.test.size, m.rmse, m.r2, byColor)
}

/** The golden JSON layout (no timings). */
fun wineJson(r: WineResult): String =
    "{\"n_rows\":${r.nRows},\"n_train\":${r.nTrain},\"n_test\":${r.nTest},\"rmse\":${r.rmse},\"r2\":${r.r2}," +
        "\"mean_quality_by_color\":{${r.meanByColor.entries.joinToString(",") { "\"${it.key}\":${it.value}" }}}}"

/** The pipeline report as an `ads:Artifact` in Turtle. */
fun reportTtl(r: WineResult): String =
    listOf(
        "@prefix ads: <https://paiml.com/ns/ads#> .",
        "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .",
        "",
        "<https://paiml.com/ns/ads#wine-report> a ads:Artifact ;",
        "  ads:schemaVersion \"1\" ;",
        "  ads:generatedBy \"agenticds::pipeline_wine\" ;",
        String.format(Locale.ROOT, "  ads:rmse \"%.10f\"^^xsd:decimal ;", r.rmse),
        "  ads:rows \"${r.nRows}\"^^xsd:integer .",
    ).joinToString("\n")
