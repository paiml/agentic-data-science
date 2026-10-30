package com.paiml.ads

import kotlin.math.abs

/** Mean quality per colour, colours sorted. */
fun meanByColor(wine: Wine): Map<String, Double> =
    wine.color.indices
        .groupBy { wine.color[it] }
        .toSortedMap()
        .mapValues { (_, i) ->
            i.sumOf { wine.quality[it] } / i.size
        }

/** True when every golden number is met within [tol]. */
fun matchesGolden(
    wine: Wine,
    split: Split,
    score: Score,
    tol: Double = GOLDEN_TOL,
): Boolean {
    val by = meanByColor(wine)
    return wine.rows == GOLDEN_ROWS &&
        split.train.rows == GOLDEN_TRAIN &&
        split.test.rows == GOLDEN_TEST &&
        abs(score.rmse - GOLDEN_RMSE) <= tol &&
        abs(score.r2 - GOLDEN_R2) <= tol &&
        abs(by.getValue("red") - GOLDEN_RED) <= tol &&
        abs(by.getValue("white") - GOLDEN_WHITE) <= tol
}

/** The ads:Artifact report in Turtle (datasets/golden). */
fun reportTtl(
    rmse: Double,
    rows: Int,
): String =
    listOf(
        "@prefix ads: <https://paiml.com/ns/ads#> .",
        "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .",
        "",
        "<https://paiml.com/ns/ads#wine-report> a ads:Artifact ;",
        "  ads:schemaVersion \"1\" ;",
        "  ads:generatedBy \"agenticds::pipeline_wine\" ;",
        "  ads:rmse \"%.10f\"^^xsd:decimal ;".format(rmse),
        "  ads:rows \"$rows\"^^xsd:integer .",
    ).joinToString("\n", postfix = "\n")
