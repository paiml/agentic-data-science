package com.paiml.ads

import org.jetbrains.kotlinx.dataframe.AnyFrame
import java.io.File
import kotlin.math.abs

/** The datasets directory, found from the penguins CSV path. */
private val DATASETS: File =
    File(PENGUINS).absoluteFile.parentFile.parentFile

/** Confusion matrix: truth in rows, prediction in columns. */
data class Scored(
    val confusion: List<List<Int>>,
) {
    fun accuracy(): Double =
        confusion.indices.sumOf { confusion[it][it] }.toDouble() /
            confusion.sumOf { it.sum() }
}

/** The fixed train/test label of each clean row. */
fun readSplit(): List<String> =
    File(DATASETS, "fixtures/split.csv")
        .readLines()
        .drop(1)
        .map { it.substringAfter(",") }

/** The fixed initial centroids, one raw-unit row per cluster. */
fun readCentroids(): List<DoubleArray> =
    File(DATASETS, "fixtures/centroids.csv")
        .readLines()
        .drop(1)
        .map { line ->
            line
                .split(",")
                .drop(1)
                .map { it.toDouble() }
                .toDoubleArray()
        }

fun AnyFrame.features(): List<DoubleArray> {
    val cols = MEASURES.map { doubles(it) }
    return List(rowsCount()) { r ->
        DoubleArray(cols.size) { cols[it][r] }
    }
}

private fun AnyFrame.labels(): List<String> =
    this["species"].values().map { it as String }

/** Fit on the train rows, score the confusion on the test rows. */
fun classify(
    df: AnyFrame,
    split: List<String>,
): Scored {
    val x = df.features()
    val names = df.labels().distinct().sorted()
    val y = df.labels().map { names.indexOf(it) }.toIntArray()
    val train = split.indices.filter { split[it] == "train" }
    val tree = fitTree(x, y, train)
    val cm = List(names.size) { IntArray(names.size) }
    split.indices.filter { split[it] == "test" }.forEach {
        cm[y[it]][tree.predict(x[it])]++
    }
    return Scored(cm.map { it.toList() })
}

private val NUMBER = Regex("-?\\d+(\\.\\d+)?")

/** The golden numbers in file order: accuracy, 9 cells, objective, 3 sizes. */
private fun goldenNumbers(): List<Double> =
    NUMBER
        .findAll(File(DATASETS, "golden/p3.json").readText())
        .map { it.value.toDouble() }
        .toList()

/** True when both models reproduce datasets/golden/p3.json. */
fun matchesGolden(
    sc: Scored,
    km: Kmeans,
): Boolean {
    val g = goldenNumbers()
    val ours =
        listOf(sc.accuracy()) +
            sc.confusion.flatten().map {
                it.toDouble()
            } +
            km.objective + km.sizes.map { it.toDouble() }
    return ours.size == g.size &&
        ours.indices.all { abs(ours[it] - g[it]) <= GOLDEN_TOL }
}
