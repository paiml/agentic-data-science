package com.paiml.ads

object RegressMain {
    /** Runtime contract: CV is out-of-fold (above in-sample error) and the species model beats plain OLS. */
    fun checkContract(
        inSample: Double,
        cvOls: Double,
        cvSpecies: Double,
    ) {
        check(cvOls > inSample) { "CV RMSE $cvOls not above in-sample $inSample: leakage" }
        check(cvSpecies < cvOls) { "species model $cvSpecies not better than OLS $cvOls" }
    }

    @JvmStatic
    fun main(args: Array<String>) {
        println(p2Json(args[0], args[1]))
        val rows = naPolicy(readPenguins(args[0]))
        val folds = readFolds(args[1])
        val y = rows.map { it.bodyMassG!! }
        val inSample = regressionMetrics(y, predict(fitOls(rows), rows)).rmse
        checkContract(inSample, cvRmse(rows, folds, false), cvRmse(rows, folds, true))
        println("contract: ads-kotlin-p2 OK")
    }
}
