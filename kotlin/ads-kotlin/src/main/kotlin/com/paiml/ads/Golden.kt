package com.paiml.ads

import java.io.File

/** Agreement bounds: R golden, and the residual sum. */
const val ORACLE_TOL = 1e-6
const val ZERO_SUM_TOL = 1e-6
private const val QUOTE = '"'
private const val NUMERIC = "-+.eE0123456789"
private const val GOLDEN_P2 = "datasets/golden/p2.json"

/** The golden file; a system property redirects it. */
private fun goldenFile() =
    File(System.getProperty("ads.golden", GOLDEN_P2))

private fun quoted(s: String) = "$QUOTE$s$QUOTE"

/** The number after "key": in a JSON object text. */
private fun number(
    json: String,
    key: String,
): Double =
    json.substringAfter(quoted(key) + ":").trim()
        .takeWhile { it in NUMERIC }.toDouble()

/** The R oracle fit: body mass on flipper length. */
fun goldenOls(): Fit {
    val text = goldenFile().readText()
    val ols = text.substringAfter(quoted("ols"))
    return Fit(
        number(ols, "intercept"),
        number(ols, "slope"),
    )
}
