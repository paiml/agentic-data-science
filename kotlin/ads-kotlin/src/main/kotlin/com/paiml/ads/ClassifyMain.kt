package com.paiml.ads

object ClassifyMain {
    const val MIN_ACCURACY = 0.95

    /** Runtime contract: held-out accuracy clears the floor and k-means keeps every row in some cluster. */
    fun checkContract(
        accuracy: Double,
        total: Int,
        clustered: Int,
    ) {
        check(accuracy >= MIN_ACCURACY) { "held-out accuracy $accuracy below $MIN_ACCURACY" }
        check(total == clustered) { "k-means lost rows: $clustered of $total" }
    }

    @JvmStatic
    fun main(args: Array<String>) {
        println(p3Json(args[0], args[1], args[2]))
        val rows = naPolicy(readPenguins(args[0]))
        val split = readSplit(args[1])
        val trainRows = rows.filterIndexed { i, _ -> split[i] == "train" }
        val classes = trainRows.map { it.species }.distinct().sorted()
        val test = rows.filterIndexed { i, _ -> split[i] == "test" }
        val tree = fitTree(trainRows, classes)
        val acc = accuracy(test.map { it.species }, test.map { predictTree(tree, it) })
        checkContract(acc, rows.size, kmeansFixed(rows, readCentroids(args[2])).sizes().sum())
        println("contract: ads-kotlin-p3 OK")
    }
}
