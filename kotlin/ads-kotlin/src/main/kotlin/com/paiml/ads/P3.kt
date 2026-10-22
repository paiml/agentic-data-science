package com.paiml.ads

import java.io.File

private const val MIN_SPLIT = 20
private const val MAX_DEPTH = 30
private const val CP = 0.01

/** Binary classification tree; class counts are kept at every node for cost-complexity pruning. */
sealed interface Tree {
    val counts: List<Int>
}

data class Leaf(val label: String, override val counts: List<Int>) : Tree

data class Split(
    val feature: Int,
    val threshold: Double,
    val left: Tree,
    val right: Tree,
    override val counts: List<Int>,
) : Tree

/** Fixed train/test label per clean row. */
fun readSplit(path: String): List<String> = File(path).readLines().drop(1).map { it.split(",")[1].trim() }

private fun features(p: Penguin): List<Double> = p.measures().map { it!! }

private fun grow(
    x: List<List<Double>>,
    y: List<Int>,
    idx: List<Int>,
    classes: List<String>,
    depth: Int,
): Tree {
    val counts = classCounts(y, idx, classes.size)
    val stop = idx.size < MIN_SPLIT || risk(counts) == 0 || depth >= MAX_DEPTH
    val cand = if (stop) null else bestSplit(x, y, idx, classes.size)
    if (cand == null) return leafOf(counts, classes)
    val (l, r) = idx.partition { x[it][cand.feature] < cand.threshold }
    val left = grow(x, y, l, classes, depth + 1)
    return Split(cand.feature, cand.threshold, left, grow(x, y, r, classes, depth + 1), counts)
}

/** Fit a Gini tree with rpart's defaults (minsplit 20, minbucket 7, maxdepth 30, cp 0.01). */
fun fitTree(
    rows: List<Penguin>,
    classes: List<String>,
): Tree {
    val x = rows.map(::features)
    val y = rows.map { classes.indexOf(it.species) }
    val tree = grow(x, y, rows.indices.toList(), classes, 0)
    return prune(tree, CP * risk(tree.counts), classes)
}

fun predictTree(
    tree: Tree,
    p: Penguin,
): String {
    var node = tree
    val x = features(p)
    while (node is Split) node = if (x[node.feature] < node.threshold) node.left else node.right
    return (node as Leaf).label
}
