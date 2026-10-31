package lab

/** A fitted line y = intercept + slope * x. */
data class Fit(
    val intercept: Double,
    val slope: Double,
)

/**
 * Least-squares line through (x, y), from the closed form:
 *   slope     = sum((x - mean x) * (y - mean y)) / sum((x - mean x)^2)
 *   intercept = mean y - slope * mean x
 *
 * Contract (the tests check each line):
 *  - x and y must have the same length, else throw IllegalArgumentException.
 *  - At least two points and a non-constant x, else throw IllegalArgumentException.
 */
fun fitOls(
    x: DoubleArray,
    y: DoubleArray,
): Fit {
    require(x.size == y.size) { "x has ${x.size} values, y has ${y.size}" }
    require(x.size >= 2) { "need at least two points, got ${x.size}" }
    val mx = x.average()
    val my = y.average()
    var sxy = 0.0
    var sxx = 0.0
    for (i in x.indices) {
        sxy += (x[i] - mx) * (y[i] - my)
        sxx += (x[i] - mx) * (x[i] - mx)
    }
    require(sxx > 0.0) { "x is constant: the slope is undefined" }
    val slope = sxy / sxx
    return Fit(intercept = my - slope * mx, slope = slope)
}

/** Sum of residuals y - (intercept + slope * x). Zero (up to rounding) for an OLS fit. */
fun residualSum(
    fit: Fit,
    x: DoubleArray,
    y: DoubleArray,
): Double = x.indices.sumOf { y[it] - (fit.intercept + fit.slope * x[it]) }
