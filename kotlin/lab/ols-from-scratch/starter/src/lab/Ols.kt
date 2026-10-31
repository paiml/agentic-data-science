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
 *
 * TODO: replace the body. Do not call a library fit; write the arithmetic.
 */
fun fitOls(
    x: DoubleArray,
    y: DoubleArray,
): Fit = TODO("lab: implement fitOls")

/** Sum of residuals y - (intercept + slope * x). Zero (up to rounding) for an OLS fit. */
fun residualSum(
    fit: Fit,
    x: DoubleArray,
    y: DoubleArray,
): Double = TODO("lab: implement residualSum")
