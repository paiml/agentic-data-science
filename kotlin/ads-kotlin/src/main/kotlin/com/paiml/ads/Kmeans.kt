package com.paiml.ads

import org.jetbrains.kotlinx.dataframe.AnyFrame
import kotlin.math.sqrt

private const val MAX_ITER = 100

/** Lloyd result: assignments, objective and cluster sizes. */
data class Kmeans(
    val cluster: List<Int>,
    val objective: Double,
    val sizes: List<Int>,
)

private fun mean(xs: List<Double>) = xs.sum() / xs.size

private fun sd(xs: List<Double>): Double {
    val m = mean(xs)
    return sqrt(xs.sumOf { (it - m) * (it - m) } / (xs.size - 1))
}

private fun dist(
    a: DoubleArray,
    b: DoubleArray,
): Double = a.indices.sumOf { (a[it] - b[it]) * (a[it] - b[it]) }

private class Scaler(x: List<DoubleArray>) {
    private val centre =
        MEASURES.indices.map {
                c ->
            mean(x.map { it[c] })
        }
    private val spread =
        MEASURES.indices.map {
                c ->
            sd(x.map { it[c] })
        }

    fun z(row: DoubleArray) =
        DoubleArray(
            row.size,
        ) { (row[it] - centre[it]) / spread[it] }
}

private fun nearest(
    p: DoubleArray,
    cen: List<DoubleArray>,
): Int = cen.indices.minBy { dist(p, cen[it]) }

private fun centroidOf(pts: List<DoubleArray>) =
    DoubleArray(MEASURES.size) { c -> mean(pts.map { it[c] }) }

private fun recentre(
    z: List<DoubleArray>,
    assign: IntArray,
    cen: MutableList<DoubleArray>,
) {
    for (k in cen.indices) {
        val m = z.filterIndexed { i, _ -> assign[i] == k }
        if (m.isNotEmpty()) cen[k] = centroidOf(m)
    }
}

private fun sse(
    z: List<DoubleArray>,
    cen: List<DoubleArray>,
    assign: IntArray,
) = z.indices.sumOf { dist(z[it], cen[assign[it]]) }

private fun sizesOf(
    assign: IntArray,
    k: Int,
) = List(k) { c -> assign.count { it == c } }

/** Lloyd k-means on z-scores from fixed centroids. */
fun cluster(
    df: AnyFrame,
    start: List<DoubleArray>,
): Kmeans {
    val scaler = Scaler(df.features())
    val z = df.features().map { scaler.z(it) }
    val cen = start.map { scaler.z(it) }.toMutableList()
    var assign = IntArray(z.size) { -1 }
    var iter = 0
    while (iter++ < MAX_ITER) {
        val next = IntArray(z.size) { nearest(z[it], cen) }
        if (next.contentEquals(assign)) break
        assign = next
        recentre(z, assign, cen)
    }
    val obj = sse(z, cen, assign)
    val sizes = sizesOf(assign, cen.size)
    return Kmeans(assign.toList(), obj, sizes)
}
