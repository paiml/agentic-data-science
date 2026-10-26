package com.paiml.ads

import org.apache.commons.math3.stat.regression.OLSMultipleLinearRegression
import org.apache.commons.math3.stat.regression.SimpleRegression
import org.jetbrains.kotlinx.dataframe.AnyFrame
import kotlin.math.abs

/** Agreement tolerance between the two library solvers. */
const val TOL = 1e-8

/** Input CSV and output plot; the system properties let the tests redirect them. */
val PENGUINS: String =
    System.getProperty(
        "ads.csv",
        "datasets/penguins/penguins.csv",
    )
val PLOT: String = System.getProperty("ads.plot", "plot.png")

data class Fit(val intercept: Double, val slope: Double) {
    /** True when both coefficients agree with [other] within [tol]. */
    fun agrees(
        other: Fit,
        tol: Double,
    ): Boolean =
        abs(intercept - other.intercept) <= tol &&
            abs(slope - other.slope) <= tol
}

/** A numeric DataFrame column as doubles. */
fun AnyFrame.doubles(name: String): DoubleArray =
    this[name].values().map {
        (it as Number).toDouble()
    }.toDoubleArray()

/** Least squares y ~ x by commons-math SimpleRegression. */
fun fitSimple(
    x: DoubleArray,
    y: DoubleArray,
): Fit {
    val reg = SimpleRegression(true)
    x.indices.forEach { reg.addData(x[it], y[it]) }
    return Fit(reg.intercept, reg.slope)
}

/** The same fit by commons-math QR decomposition (independent code path). */
fun fitQr(
    x: DoubleArray,
    y: DoubleArray,
): Fit {
    val reg = OLSMultipleLinearRegression()
    reg.newSampleData(y, Array(x.size) { doubleArrayOf(x[it]) })
    val beta = reg.estimateRegressionParameters()
    return Fit(beta[0], beta[1])
}

/** Sum of residuals y - (a + b x); zero for any OLS fit with an intercept. */
fun residualSum(
    fit: Fit,
    x: DoubleArray,
    y: DoubleArray,
): Double =
    x.indices.sumOf {
        y[it] - (fit.intercept + fit.slope * x[it])
    }

/** Fail loudly when NA handling changed the row count. */
fun expectRows(
    actual: Int,
    expected: Int,
) = check(actual == expected) {
    "rows used $actual, expected $expected"
}
