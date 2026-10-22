package com.paiml.ads

/** Confusion matrix, truth in rows and prediction in columns. */
fun confusion(
    truth: List<String>,
    pred: List<String>,
    classes: List<String>,
): List<List<Int>> = classes.map { t -> classes.map { p -> truth.indices.count { truth[it] == t && pred[it] == p } } }

fun accuracy(
    truth: List<String>,
    pred: List<String>,
): Double = truth.indices.count { truth[it] == pred[it] }.toDouble() / truth.size
