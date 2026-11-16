package com.paiml.ads

/** One line: rows read and rows kept by the NA policy. */
fun ingestLine(path: String): String {
    val rows = readPenguins(path)
    return "rows=${rows.size} kept=${naPolicy(rows).size}"
}
