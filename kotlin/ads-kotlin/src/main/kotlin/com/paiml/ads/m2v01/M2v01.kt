package com.paiml.ads.m2v01

import com.paiml.ads.FLIPPER
import com.paiml.ads.MASS
import com.paiml.ads.ORACLE_TOL
import com.paiml.ads.ZERO_SUM_TOL
import com.paiml.ads.doubles
import com.paiml.ads.emitContract
import com.paiml.ads.fitQr
import com.paiml.ads.goldenOls
import com.paiml.ads.loadClean
import com.paiml.ads.residualSum
import com.paiml.ads.show
import com.paiml.ads.verdict
import kotlin.math.abs

fun main() {
    // Clean the two model columns, then fit by QR.
    val df = loadClean()
    val x = df.doubles(FLIPPER)
    val y = df.doubles(MASS)
    val fit = fitQr(x, y)
    show("intercept", "%.2f".format(fit.intercept))
    show("slope", "%.2f".format(fit.slope))

    // With an intercept, residuals sum to zero.
    val res = residualSum(fit, x, y)
    show("residuals", "%.1e".format(res))
    val zero = abs(res) < ZERO_SUM_TOL
    verdict(zero, "Residual sum")

    // The fit must match the R golden within 1e-6.
    val gold = goldenOls()
    val golden = fit.agrees(gold, ORACLE_TOL)
    verdict(golden, "Golden P2")
    emitContract(
        "ads-kotlin-p2-v1",
        "residuals %.1e slope %.2f".format(res, fit.slope),
        zero and golden,
    )
}
