package com.paiml.ads

private const val MIN_BUCKET = 7

internal class Candidate(val improvement: Double, val feature: Int, val threshold: Double)

private fun gini(
    counts: List<Int>,
    n: Int,
): Double = 1.0 - counts.sumOf { (it.toDouble() / n) * (it.toDouble() / n) }

internal fun risk(counts: List<Int>): Int = counts.sum() - counts.max()

internal fun leafOf(
    counts: List<Int>,
    classes: List<String>,
): Leaf = Leaf(classes[counts.indexOf(counts.max())], counts)

internal fun classCounts(
    y: List<Int>,
    idx: List<Int>,
    k: Int,
): List<Int> = IntArray(k).also { c -> idx.forEach { c[y[it]]++ } }.toList()

/** Best split of one feature: sweep the sorted rows, keep the first strictly better Gini gain. */
private fun sweep(
    values: List<Double>,
    labels: List<Int>,
    total: List<Int>,
    feature: Int,
): Candidate? {
    val n = values.size
    val parent = n * gini(total, n)
    val left = IntArray(total.size)
    var best: Candidate? = null
    for (i in 0 until n - 1) {
        left[labels[i]]++
        val nl = i + 1
        val ok = values[i] < values[i + 1] && nl >= MIN_BUCKET && n - nl >= MIN_BUCKET
        val right = total.indices.map { total[it] - left[it] }
        val gain = parent - nl * gini(left.toList(), nl) - (n - nl) * gini(right, n - nl)
        if (ok && gain > (best?.improvement ?: 0.0)) best = Candidate(gain, feature, (values[i] + values[i + 1]) / 2)
    }
    return best
}

/** Best Gini split over all features; the first feature and lowest threshold win ties. */
internal fun bestSplit(
    x: List<List<Double>>,
    y: List<Int>,
    idx: List<Int>,
    k: Int,
): Candidate? {
    val total = classCounts(y, idx, k)
    var best: Candidate? = null
    for (f in x[0].indices) {
        val order = idx.sortedBy { x[it][f] }
        val cand = sweep(order.map { x[it][f] }, order.map { y[it] }, total, f)
        if (cand != null && cand.improvement > (best?.improvement ?: 0.0)) best = cand
    }
    return best
}
