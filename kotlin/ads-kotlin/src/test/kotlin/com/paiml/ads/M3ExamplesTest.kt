package com.paiml.ads

import com.fasterxml.jackson.databind.ObjectMapper
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.PrintStream
import kotlin.math.abs

private const val SHIFT = 5.0
private val golden =
    ObjectMapper().readTree(
        File(
            System.getProperty("ads.root"),
            "datasets/golden/p3.json",
        ),
    )

/** An independent Lloyd oracle: nested loops on z-scores. */
private fun oracle(
    df: org.jetbrains.kotlinx.dataframe.AnyFrame,
    start: List<DoubleArray>,
): Pair<List<Int>, Double> {
    val cols = MEASURES.map { df.doubles(it) }
    val n = cols[0].size
    val mu = cols.map { it.average() }
    val s =
        cols.mapIndexed { j, c ->
            Math.sqrt(
                c.sumOf { (it - mu[j]) * (it - mu[j]) } / (n - 1),
            )
        }
    val z =
        Array(
            n,
        ) { i -> DoubleArray(4) { (cols[it][i] - mu[it]) / s[it] } }
    val c =
        start.map { r ->
            DoubleArray(4) { (r[it] - mu[it]) / s[it] }
        }
    val a = IntArray(n)
    repeat(100) {
        for (i in 0 until n) {
            var b = 0
            for (k in c.indices) {
                if (d2(z[i], c[k]) < d2(z[i], c[b])) b = k
            }
            a[i] = b + 1
        }
        for (k in c.indices) {
            val m = (0 until n).filter { a[it] == k + 1 }
            if (m.isNotEmpty()) {
                for (j in 0 until 4) {
                    c[k][j] = m.sumOf { z[it][j] } / m.size
                }
            }
        }
    }
    val obj = (0 until n).sumOf { d2(z[it], c[a[it] - 1]) }
    return a.toList() to obj
}

private val gk = golden["kmeans"]

private fun d2(
    a: DoubleArray,
    b: DoubleArray,
) = a.indices.sumOf { (a[it] - b[it]) * (a[it] - b[it]) }

class M3ExamplesTest {
    private val df = loadClean()
    private val split = readSplit()
    private val start = readCentroids()

    @Test
    fun exampleM3v01PrintsTheVerdict() {
        val old = System.out
        val buf = ByteArrayOutputStream()
        System.setOut(PrintStream(buf, true))
        try {
            com.paiml.ads.m3v01
                .main()
        } finally {
            System.setOut(old)
        }
        assertTrue(
            "VERDICT: P3 matches golden PASS" in buf.toString(),
        )
    }

    @Test
    fun classifyMatchesGoldenExactly() {
        val sc = classify(df, split)
        assertEquals(
            golden["accuracy"].asDouble(),
            sc.accuracy(),
            GOLDEN_TOL,
        )
        assertEquals(
            golden["confusion"].map { r -> r.map { it.asInt() } },
            sc.confusion,
        )
    }

    @Test
    fun kmeansMatchesGoldenAndTheOracle() {
        val km = cluster(df, start)
        val (ref, obj) = oracle(df, start)
        assertEquals(
            gk["objective"].asDouble(),
            km.objective,
            GOLDEN_TOL,
        )
        assertEquals(
            gk["cluster_sizes"].map { it.asInt() },
            km.sizes,
        )
        assertTrue(abs(obj - km.objective) <= GOLDEN_TOL)
        assertEquals(ref, km.cluster.map { it + 1 })
        assertTrue(matchesGolden(classify(df, split), km))
    }

    @Test
    fun movedStartingCentroidsFailTheGolden() {
        val moved =
            start.map { r ->
                r.map { it + SHIFT }.toDoubleArray()
            }
        val sc = classify(df, split)
        assertFalse(
            matchesGolden(sc, cluster(df, moved.reversed())),
        )
    }

    @Test
    fun matchesGoldenRejectsAWrongConfusion() {
        val km = cluster(df, start)
        val sc = classify(df, split)
        val bad = Scored(sc.confusion.reversed())
        assertFalse(matchesGolden(bad, km))
    }

    @Test
    fun giniOfPureAndEvenNodes() {
        assertEquals(0.0, gini(intArrayOf(4, 0)), 0.0)
        assertEquals(0.5, gini(intArrayOf(5, 5)), 1e-12)
    }

    @Test
    fun cleanSeparationSplitsAtTheMidpoint() {
        val x = List(40) { doubleArrayOf(it.toDouble()) }
        val y = IntArray(40) { if (it < 20) 0 else 1 }
        val tree = fitTree(x, y, x.indices.toList()) as Cut
        assertEquals(19.5, tree.cut, GOLDEN_TOL)
        assertEquals(0, tree.predict(doubleArrayOf(3.0)))
        assertEquals(1, tree.predict(doubleArrayOf(30.0)))
    }

    @Test
    fun smallOrPureOrConstantNodesStayLeaves() {
        val x = List(30) { doubleArrayOf(it.toDouble()) }
        val rows = x.indices.toList()
        val small =
            fitTree(x, IntArray(30) { it % 2 }, rows.take(10))
        assertTrue(small is Leaf)
        assertTrue(fitTree(x, IntArray(30), rows) is Leaf)
        val flat = List(30) { doubleArrayOf(1.0) }
        val mixed = IntArray(30) { if (it < 15) 0 else 1 }
        assertTrue(fitTree(flat, mixed, rows) is Leaf)
    }

    @Test
    fun aSplitThatSavesNoErrorsIsPruned() {
        val x = List(30) { doubleArrayOf(it.toDouble()) }
        val y =
            IntArray(
                30,
            ) { if (it in 8..10 || it in 20..22) 1 else 0 }
        val tree = fitTree(x, y, x.indices.toList())
        assertTrue(tree is Leaf)
    }

    @Test
    fun anEmptyClusterKeepsItsCentroid() {
        val far = start + doubleArrayOf(1e6, 1e6, 1e6, 1e6)
        assertEquals(0, cluster(df, far).sizes.last())
    }
}
