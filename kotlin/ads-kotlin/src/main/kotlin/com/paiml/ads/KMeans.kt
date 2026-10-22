package com.paiml.ads

import java.io.File
import kotlin.math.sqrt

private const val MAX_ITER = 100

data class KMeansResult(val cluster: List<Int>, val objective: Double, val k: Int) {
    fun sizes(): List<Int> = (0 until k).map { c -> cluster.count { it == c } }
}

/** Fixed initial centroids in raw units, one row per cluster, in measurement-column order. */
fun readCentroids(path: String): List<List<Double>> =
    File(path).readLines().drop(1).map { line -> line.split(",").drop(1).map { it.trim().toDouble() } }

private fun sqDist(
    a: List<Double>,
    b: List<Double>,
): Double = a.indices.sumOf { (a[it] - b[it]) * (a[it] - b[it]) }

/** Lloyd k-means on z-scored features (sample SD) from fixed initial centroids; ties go to the first cluster. */
fun kmeansFixed(
    rows: List<Penguin>,
    centroids: List<List<Double>>,
    maxIter: Int = MAX_ITER,
): KMeansResult {
    require(rows.size >= 2) { "k-means needs at least two rows" }
    val raw = rows.map { r -> r.measures().map { it!! } }
    val dims = raw[0].indices
    val centre = dims.map { d -> raw.sumOf { it[d] } / raw.size }
    val spread = dims.map { d -> sqrt(raw.sumOf { (it[d] - centre[d]) * (it[d] - centre[d]) } / (raw.size - 1)) }
    require(spread.all { it > 0.0 }) { "a measurement column has zero variance" }
    val z = raw.map { r -> dims.map { (r[it] - centre[it]) / spread[it] } }
    val cen = centroids.map { c -> dims.map { (c[it] - centre[it]) / spread[it] } }.toMutableList()
    var cluster = List(z.size) { -1 }
    for (@Suppress("UnusedPrivateProperty") iter in 1..maxIter) {
        val next = z.map { p -> cen.indices.minBy { sqDist(p, cen[it]) } }
        if (next == cluster) break
        cluster = next
        for (k in cen.indices) {
            val members = z.filterIndexed { i, _ -> cluster[i] == k }
            if (members.isNotEmpty()) cen[k] = dims.map { d -> members.sumOf { it[d] } / members.size }
        }
    }
    return KMeansResult(cluster, z.indices.sumOf { sqDist(z[it], cen[cluster[it]]) }, cen.size)
}
