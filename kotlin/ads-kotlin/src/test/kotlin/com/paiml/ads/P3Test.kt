package com.paiml.ads

import com.fasterxml.jackson.databind.ObjectMapper
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.ByteArrayOutputStream
import java.io.PrintStream
import java.nio.file.Files
import java.nio.file.Path

private val root3: Path = Path.of(System.getProperty("ads.root"))
private val csv3: String = root3.resolve("datasets/penguins/penguins.csv").toString()
private val splitPath: String = root3.resolve("datasets/fixtures/split.csv").toString()
private val centroidsPath: String = root3.resolve("datasets/fixtures/centroids.csv").toString()
private const val TOL3 = 1e-8

private fun pt(
    species: String,
    flipper: Double,
    bill: Double = 40.0,
) = Penguin(species, bill, 18.0, flipper, 3500.0)

class P3Test {
    private val golden = ObjectMapper().readTree(root3.resolve("datasets/golden/p3.json").toFile())
    private val rows = naPolicy(readPenguins(csv3))
    private val split = readSplit(splitPath)
    private val train = rows.filterIndexed { i, _ -> split[i] == "train" }
    private val test = rows.filterIndexed { i, _ -> split[i] == "test" }
    private val classes = rows.map { it.species }.distinct().sorted()

    @Test
    fun splitIsFixedAndCoversEveryCleanRow() {
        assertEquals(rows.size, split.size)
        assertEquals(setOf("train", "test"), split.toSet())
        assertEquals(257, train.size)
        assertEquals(85, test.size)
    }

    @Test
    fun treeMatchesRpartStructure() {
        val t = fitTree(train, classes) as Split
        assertEquals(2, t.feature)
        assertEquals(207.5, t.threshold, 0.0)
        val l = t.left as Split
        assertEquals(0, l.feature)
        assertEquals(43.35, l.threshold, 1e-9)
        assertEquals("Gentoo", (t.right as Leaf).label)
        assertEquals("Adelie", (l.left as Leaf).label)
        assertEquals("Chinstrap", (l.right as Leaf).label)
    }

    @Test
    fun accuracyAndConfusionMatchGolden() {
        val tree = fitTree(train, classes)
        val pred = test.map { predictTree(tree, it) }
        val cm = confusion(test.map { it.species }, pred, classes)
        assertEquals(golden["classes"].map { it.asText() }, classes)
        for (i in cm.indices) assertEquals(golden["confusion"][i].map { it.asInt() }, cm[i])
        assertEquals(golden["accuracy"].asDouble(), accuracy(test.map { it.species }, pred), TOL3)
    }

    @Test
    fun kmeansMatchesGolden() {
        val km = kmeansFixed(rows, readCentroids(centroidsPath))
        assertEquals(golden["kmeans"]["objective"].asDouble(), km.objective, TOL3)
        assertEquals(golden["kmeans"]["cluster_sizes"].map { it.asInt() }, km.sizes())
    }

    @Test
    fun smallNodeIsNotSplit() {
        val tiny = (1..19).map { pt(if (it <= 10) "A" else "B", it.toDouble()) }
        assertTrue(fitTree(tiny, listOf("A", "B")) is Leaf)
    }

    @Test
    fun splitRespectsMinBucket() {
        val pts = (1..6).map { pt("A", it.toDouble()) } + (7..30).map { pt("B", it.toDouble()) }
        val t = fitTree(pts, listOf("A", "B")) as Split
        assertEquals(7.5, t.threshold, 0.0)
    }

    @Test
    fun cleanSeparationSplitsAtMidpoint() {
        val pts = (1..15).map { pt("A", it.toDouble()) } + (16..30).map { pt("B", it.toDouble()) }
        val t = fitTree(pts, listOf("A", "B")) as Split
        assertEquals(15.5, t.threshold, 0.0)
        assertEquals("A", predictTree(t, pt("A", 3.0)))
        assertEquals("B", predictTree(t, pt("B", 20.0)))
        assertEquals("B", predictTree(t, pt("A", 15.5)), "a value equal to the threshold goes right, as in rpart")
    }

    @Test
    fun pureNodeIsALeaf() {
        assertTrue(fitTree((1..30).map { pt("A", it.toDouble()) }, listOf("A")) is Leaf)
    }

    @Test
    fun weakSplitIsPrunedByComplexity() {
        val pts = (1..300).map { pt(if (it % 2 == 0) "A" else "B", it.toDouble()) }
        assertTrue(fitTree(pts, listOf("A", "B")) is Leaf, "each split buys 1 of 150 root risk, under cp = 1%")
    }

    @Test
    fun accuracyAndConfusionBasics() {
        assertEquals(0.5, accuracy(listOf("A", "B"), listOf("A", "A")), 0.0)
        val cm = confusion(listOf("A", "B", "B"), listOf("A", "A", "B"), listOf("A", "B"))
        assertEquals(listOf(listOf(1, 0), listOf(1, 1)), cm)
    }

    @Test
    fun kmeansStopsAtIterationCap() {
        val pts = rows.take(40)
        val cen = readCentroids(centroidsPath)
        val one = kmeansFixed(pts, cen, maxIter = 1)
        assertEquals(pts.size, one.cluster.size)
        assertTrue(one.objective >= kmeansFixed(pts, cen).objective - 1e-9)
    }

    @Test
    fun kmeansKeepsAnEmptyClusterWhereItWas() {
        val far = listOf(listOf(1000.0, 1000.0, 1000.0, 1000.0))
        val cen = readCentroids(centroidsPath).take(2) + far
        val km = kmeansFixed(rows.take(60), cen)
        assertEquals(0, km.sizes()[2])
        assertEquals(60, km.sizes().sum())
    }

    @Test
    fun kmeansRefusesDegenerateInput() {
        val cen = readCentroids(centroidsPath)
        assertThrows(IllegalArgumentException::class.java) { kmeansFixed(rows.take(1), cen) }
        val flat = rows.take(5).map { it.copy(billLengthMm = 1.0) }
        assertThrows(IllegalArgumentException::class.java) { kmeansFixed(flat, cen) }
    }

    @Test
    fun readersParseFiles() {
        val s = Files.createTempFile("split", ".csv")
        val c = Files.createTempFile("cen", ".csv")
        Files.writeString(s, "row,set\n1,test\n2,train\n")
        Files.writeString(c, "cluster,bill_length_mm,bill_depth_mm,flipper_length_mm,body_mass_g\n1,1.5,2,3,4\n")
        try {
            assertEquals(listOf("test", "train"), readSplit(s.toString()))
            assertEquals(listOf(listOf(1.5, 2.0, 3.0, 4.0)), readCentroids(c.toString()))
        } finally {
            Files.delete(s)
            Files.delete(c)
        }
    }

    @Test
    fun p3JsonHasGoldenKeysAndValues() {
        val out = ObjectMapper().readTree(p3Json(csv3, splitPath, centroidsPath))
        assertEquals(golden.fieldNames().asSequence().toList(), out.fieldNames().asSequence().toList())
        assertEquals(golden["accuracy"].asDouble(), out["accuracy"].asDouble(), TOL3)
        assertEquals(golden["confusion"], out["confusion"])
        assertEquals(golden["classes"], out["classes"])
        assertEquals(golden["kmeans"]["objective"].asDouble(), out["kmeans"]["objective"].asDouble(), TOL3)
        assertEquals(golden["kmeans"]["cluster_sizes"], out["kmeans"]["cluster_sizes"])
    }

    @Test
    fun splitLengthMismatchIsRefused() {
        val f = Files.createTempFile("split", ".csv")
        Files.writeString(f, "row,set\n1,train\n")
        try {
            assertThrows(IllegalArgumentException::class.java) { p3Json(csv3, f.toString(), centroidsPath) }
        } finally {
            Files.delete(f)
        }
    }

    @Test
    fun mainPrintsContractLine() {
        val buf = ByteArrayOutputStream()
        val old = System.out
        System.setOut(PrintStream(buf))
        try {
            ClassifyMain.main(arrayOf(csv3, splitPath, centroidsPath))
        } finally {
            System.setOut(old)
        }
        assertTrue(buf.toString().lines().any { it == "contract: ads-kotlin-p3 OK" })
    }

    @Test
    fun contractRefusesBadAccuracyAndBadKmeans() {
        ClassifyMain.checkContract(0.97, 3, 3)
        assertThrows(IllegalStateException::class.java) { ClassifyMain.checkContract(0.5, 3, 3) }
        assertThrows(IllegalStateException::class.java) { ClassifyMain.checkContract(0.97, 3, 2) }
    }
}
