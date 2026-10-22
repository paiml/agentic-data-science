package com.paiml.ads

/** Serialise P3 results to the golden JSON layout. */
fun p3Json(
    csvPath: String,
    splitPath: String,
    centroidsPath: String,
): String {
    val rows = naPolicy(readPenguins(csvPath))
    val split = readSplit(splitPath)
    require(split.size == rows.size) { "split file has ${split.size} labels for ${rows.size} rows" }
    val trainRows = rows.filterIndexed { i, _ -> split[i] == "train" }
    val classes = trainRows.map { it.species }.distinct().sorted()
    val test = rows.filterIndexed { i, _ -> split[i] == "test" }
    val tree = fitTree(trainRows, classes)
    val truth = test.map { it.species }
    val pred = test.map { predictTree(tree, it) }
    val km = kmeansFixed(rows, readCentroids(centroidsPath))
    val cm = confusion(truth, pred, classes).joinToString(",") { it.toString() }
    return "{\"accuracy\":${accuracy(truth, pred)},\"confusion\":[$cm]," +
        "\"classes\":[${classes.joinToString(",") { "\"$it\"" }}]," +
        "\"kmeans\":{\"objective\":${km.objective},\"cluster_sizes\":${km.sizes()}}}"
}
