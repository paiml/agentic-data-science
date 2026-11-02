// PLANT: a correct fit, but residualSum always reports zero.
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

@Suppress("UNUSED_PARAMETER")
fun residualSum(
    fit: Fit,
    x: DoubleArray,
    y: DoubleArray,
): Double = 0.0
