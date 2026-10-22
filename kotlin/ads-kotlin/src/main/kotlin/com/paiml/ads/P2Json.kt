package com.paiml.ads

private fun metricsJson(m: Metrics) = "{\"rmse\":${m.rmse},\"r2\":${m.r2}}"

private fun coefJson(m: Model) = m.coef.entries.joinToString(",") { "\"${it.key}\":${it.value}" }

/** Serialise P2 results to the golden JSON layout. */
fun p2Json(
    csvPath: String,
    foldsPath: String,
): String {
    val rows = naPolicy(readPenguins(csvPath))
    val folds = readFolds(foldsPath)
    val ols = fitOls(rows)
    val sp = fitSpecies(rows)
    val y = rows.map { it.bodyMassG!! }
    return "{\"ols\":{\"intercept\":${ols.coef["(Intercept)"]},\"slope\":${ols.coef["flipper_length_mm"]}}," +
        "\"species_model\":{${coefJson(sp)}}," +
        "\"metrics\":{\"ols\":${metricsJson(regressionMetrics(y, predict(ols, rows)))}," +
        "\"species\":${metricsJson(regressionMetrics(y, predict(sp, rows)))}}," +
        "\"cv_rmse\":{\"ols\":${cvRmse(rows, folds, false)},\"species\":${cvRmse(rows, folds, true)}}}"
}
