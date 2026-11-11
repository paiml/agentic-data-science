// PLANT: a correct fit with no input validation at all.
package lab

data class Fit(
    val intercept: Double,
    val slope: Double,
)

fun fitOls(
    x: DoubleArray,
    y: DoubleArray,
): Fit {
    val mx = x.average()
    val my = y.average()
    var sxy = 0.0
    var sxx = 0.0
    for (i in x.indices) {
        sxy += (x[i] - mx) * (y[i] - my)
        sxx += (x[i] - mx) * (x[i] - mx)
    }
    val slope = sxy / sxx
    return Fit(intercept = my - slope * mx, slope = slope)
}

fun residualSum(
    fit: Fit,
    x: DoubleArray,
    y: DoubleArray,
): Double = x.indices.sumOf { y[it] - (fit.intercept + fit.slope * x[it]) }

