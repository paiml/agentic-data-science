package com.paiml.ads

import java.io.File
import kotlin.math.abs
import kotlin.math.sqrt

private const val PIVOT_EPS = 1e-12 // relative to the largest diagonal entry of X'X

/** A fitted linear model: named coefficients plus the species dummy levels it was fitted with. */
data class Model(val coef: Map<String, Double>, val levels: List<String>)

data class Metrics(val rmse: Double, val r2: Double)

/** Fixed fold id per clean row (never from an RNG). */
fun readFolds(path: String): List<Int> = File(path).readLines().drop(1).map { it.split(",")[1].trim().toInt() }

private fun designRow(
    p: Penguin,
    levels: List<String>,
): List<Double> = listOf(1.0, p.flipperLengthMm!!) + levels.map { if (p.species == it) 1.0 else 0.0 }

private val BASE_NAMES = listOf("(Intercept)", "flipper_length_mm")

private fun names(levels: List<String>): List<String> = BASE_NAMES + levels.map { "species$it" }

/** Solve the normal equations X'X b = X'y by Gauss-Jordan with partial pivoting; refuses a singular design. */
internal fun solveNormal(
    x: List<List<Double>>,
    y: List<Double>,
): List<Double> {
    val k = x[0].size
    val a =
        Array(k) { i ->
            DoubleArray(k + 1) { j ->
                if (j < k) x.sumOf { it[i] * it[j] } else x.indices.sumOf { r -> x[r][i] * y[r] }
            }
        }
    val scale = (0 until k).maxOf { abs(a[it][it]) }
    for (c in 0 until k) {
        val p = (c until k).maxBy { abs(a[it][c]) }
        require(abs(a[p][c]) > PIVOT_EPS * scale) { "singular design matrix" }
        a[c] = a[p].also { a[p] = a[c] }
        for (r in (0 until k).filter { it != c }) {
            val f = a[r][c] / a[c][c]
            for (j in (c..k).toList()) a[r][j] -= f * a[c][j]
        }
    }
    return List(k) { a[it][k] / a[it][it] }
}

private fun fit(
    rows: List<Penguin>,
    levels: List<String>,
): Model {
    val b = solveNormal(rows.map { designRow(it, levels) }, rows.map { it.bodyMassG!! })
    return Model(names(levels).zip(b).toMap(), levels)
}

/** Closed-form simple OLS of body mass on flipper length. */
fun fitOls(rows: List<Penguin>): Model = fit(rows, emptyList())

/** Body mass on flipper length and species (first sorted species is the baseline, as in R). */
fun fitSpecies(rows: List<Penguin>): Model = fit(rows, rows.map { it.species }.distinct().sorted().drop(1))

fun predict(
    model: Model,
    rows: List<Penguin>,
): List<Double> =
    rows.map { p ->
        designRow(p, model.levels).zip(names(model.levels)).sumOf { (v, n) -> v * model.coef.getValue(n) }
    }

/** RMSE and R squared of predictions. */
fun regressionMetrics(
    y: List<Double>,
    yhat: List<Double>,
): Metrics {
    val sse = y.indices.sumOf { (y[it] - yhat[it]) * (y[it] - yhat[it]) }
    val mean = y.sum() / y.size
    val sst = y.sumOf { (it - mean) * (it - mean) }
    return Metrics(sqrt(sse / y.size), 1 - sse / sst)
}

/** Pooled out-of-fold RMSE: each fold is predicted by a model fitted without it. */
fun cvRmse(
    rows: List<Penguin>,
    folds: List<Int>,
    withSpecies: Boolean,
): Double {
    require(folds.size == rows.size) { "fold file has ${folds.size} ids for ${rows.size} rows" }
    require(folds.distinct().size > 1) { "need at least two folds: one fold leaves no training rows" }
    val levels = if (withSpecies) rows.map { it.species }.distinct().sorted().drop(1) else emptyList()
    val pred = DoubleArray(rows.size)
    for (k in folds.distinct().sorted()) {
        val test = rows.indices.filter { folds[it] == k }
        val model = fit(rows.filterIndexed { i, _ -> folds[i] != k }, levels)
        predict(model, test.map { rows[it] }).forEachIndexed { j, v -> pred[test[j]] = v }
    }
    return regressionMetrics(rows.map { it.bodyMassG!! }, pred.toList()).rmse
}
