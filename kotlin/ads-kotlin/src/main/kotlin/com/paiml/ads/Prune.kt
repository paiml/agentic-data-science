package com.paiml.ads

private fun leaves(t: Tree): Int = if (t is Split) leaves(t.left) + leaves(t.right) else 1

private fun subtreeRisk(t: Tree): Int = if (t is Split) subtreeRisk(t.left) + subtreeRisk(t.right) else risk(t.counts)

/** Cost-complexity pruning at alpha (a split must buy `alpha` risk per extra leaf), bottom-up. */
internal fun prune(
    t: Tree,
    alpha: Double,
    classes: List<String>,
): Tree {
    if (t !is Split) return t
    val kept = t.copy(left = prune(t.left, alpha, classes), right = prune(t.right, alpha, classes))
    val buys = (risk(kept.counts) - subtreeRisk(kept)).toDouble() / (leaves(kept) - 1)
    return if (buys < alpha) leafOf(kept.counts, classes) else kept
}
