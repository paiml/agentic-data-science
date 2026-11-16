// PLANT: fits the mean only (slope zero), a plausible-looking line that explains nothing.
package lab

data class Fit(
    val intercept: Double,
    val slope: Double,
)

fun fitOls(
    x: DoubleArray,
    y: DoubleArray,
): Fit {
    require(x.size == y.size)
    require(x.size >= 2)
    require(x.toSet().size > 1)
    return Fit(intercept = y.average(), slope = 0.0)
}

fun residualSum(
    fit: Fit,
    x: DoubleArray,
    y: DoubleArray,
): Double = x.indices.sumOf { y[it] - (fit.intercept + fit.slope * x[it]) }

