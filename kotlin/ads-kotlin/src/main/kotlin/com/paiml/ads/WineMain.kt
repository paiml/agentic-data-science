package com.paiml.ads

import kotlin.math.abs

object WineMain {
    /** Runtime contract: the split loses no rows and the model beats predicting the mean. */
    fun checkContract(res: WineResult) {
        check(res.nTrain + res.nTest == res.nRows) { "split lost rows: ${res.nTrain}+${res.nTest} != ${res.nRows}" }
        check(res.r2 > 0.0) { "held-out R2 ${res.r2} does not beat the mean predictor" }
    }

    @JvmStatic
    fun main(args: Array<String>) {
        val res = pipelineWine(readWine(args[0], args[1]))
        checkContract(res)
        println(wineJson(res))
        println("contract: ads-kotlin-p4 OK")
    }
}

object BenchMain {
    private const val DEFAULT_REPS = 20
    private const val AGG_TOL = 1e-12

    /** Runtime contract: both engines return the same per-colour aggregate before any timing is shown. */
    fun checkContract(
        a: List<ColorAgg>,
        b: List<ColorAgg>,
    ) {
        check(a.map { it.color } == b.map { it.color }) { "engines disagree on groups" }
        check(a.map { it.n } == b.map { it.n }) { "engines disagree on counts" }
        check(a.indices.all { abs(a[it].meanQuality - b[it].meanQuality) <= AGG_TOL }) { "engines disagree on means" }
    }

    @JvmStatic
    fun main(args: Array<String>) {
        val rows = validateWine(readWine(args[0], args[1]))
        checkContract(aggregateFrame(rows), aggregateMap(rows))
        benchWine(rows, args.getOrNull(2)?.toInt() ?: DEFAULT_REPS).forEach { println("${it.engine}\t${it.seconds}") }
        println("contract: ads-kotlin-p4-bench OK")
    }
}
