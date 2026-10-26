package com.paiml.ads

private const val MIN_SPLIT = 20
private const val MIN_BUCKET = 7
private const val CP = 0.01

/** A decision tree: a leaf class or a split x[col] < cut. */
sealed interface Tree

data class Leaf(val label: Int) : Tree

data class Cut(
    val col: Int,
    val cut: Double,
    val left: Tree,
    val right: Tree,
) : Tree

/** Gini impurity 1 - sum p_k^2 of class counts. */
fun gini(counts: IntArray): Double {
    val n = counts.sum().toDouble()
    return 1.0 - counts.sumOf { (it / n) * (it / n) }
}

private fun tally(
    y: IntArray,
    rows: List<Int>,
    k: Int,
): IntArray = IntArray(k).also { c -> rows.forEach { c[y[it]]++ } }

private fun errors(counts: IntArray) = counts.sum() - counts.max()

private class Best(
    val gain: Double,
    val col: Int,
    val cut: Double,
) {
    fun goesLeft(row: DoubleArray) = row[col] < cut
}

private fun fits(
    nl: Int,
    nr: Int,
) = nl >= MIN_BUCKET && nr >= MIN_BUCKET

private fun cost(c: IntArray) = c.sum() * gini(c)

/** Best gini split of [rows] on one column, or null. */
private fun bestOnColumn(
    x: List<DoubleArray>,
    y: IntArray,
    rows: List<Int>,
    col: Int,
): Best? {
    val k = y.max() + 1
    val order = rows.sortedBy { x[it][col] }
    val total = tally(y, rows, k)
    val parent = cost(total)
    val left = IntArray(k)
    var best: Best? = null
    for (i in 0 until order.size - 1) {
        left[y[order[i]]]++
        val a = x[order[i]][col]
        val b = x[order[i + 1]][col]
        val nl = i + 1
        val nr = order.size - nl
        if (a < b && fits(nl, nr)) {
            val rest = IntArray(k) { total[it] - left[it] }
            val gain = parent - cost(left) - cost(rest)
            if (gain > (best?.gain ?: 0.0)) {
                best = Best(gain, col, (a + b) / 2)
            }
        }
    }
    return best
}

/** The best split over all columns, or null for a leaf. */
private fun bestSplit(
    x: List<DoubleArray>,
    y: IntArray,
    rows: List<Int>,
    counts: IntArray,
): Best? =
    if (rows.size < MIN_SPLIT || errors(counts) == 0) {
        null
    } else {
        x[0].indices.mapNotNull { bestOnColumn(x, y, rows, it) }
            .maxByOrNull { it.gain }
    }

private fun grow(
    x: List<DoubleArray>,
    y: IntArray,
    rows: List<Int>,
    minGain: Double,
): Tree {
    val k = y.max() + 1
    val counts = tally(y, rows, k)
    val leaf = Leaf(counts.indices.maxBy { counts[it] })
    val best = bestSplit(x, y, rows, counts)
    if (best == null) return leaf
    val (l, r) = rows.partition { best.goesLeft(x[it]) }
    val saved =
        errors(counts) - errors(tally(y, l, k)) -
            errors(tally(y, r, k))
    return if (saved < minGain) {
        leaf
    } else {
        Cut(
            best.col,
            best.cut,
            grow(x, y, l, minGain),
            grow(x, y, r, minGain),
        )
    }
}

/** Fit a gini tree (rpart defaults) on [rows]. */
fun fitTree(
    x: List<DoubleArray>,
    y: IntArray,
    rows: List<Int>,
): Tree {
    val rootErrors = errors(tally(y, rows, y.max() + 1))
    return grow(x, y, rows, CP * rootErrors)
}

/** The class a tree predicts for one feature row. */
fun Tree.predict(row: DoubleArray): Int =
    when (this) {
        is Leaf -> label
        is Cut ->
            if (row[col] < cut) {
                left.predict(row)
            } else {
                right.predict(row)
            }
    }
