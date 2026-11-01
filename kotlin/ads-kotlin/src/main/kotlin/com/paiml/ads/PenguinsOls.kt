package com.paiml.ads

import java.util.Locale

/**
 * Provable contract: ads-kotlin-p2-v1, printed only after both solvers agree.
 */
fun main() {
    showVersions()

    // Load; drop NA in the two model columns.
    val df = loadClean()
    show("rows used", "${df.rowsCount()}")

    // Fit body mass on flipper length, two solvers.
    val x = df.doubles(FLIPPER)
    val y = df.doubles(MASS)
    val fit = fitSimple(x, y)
    val qr = fitQr(x, y)
    show("intercept", "%.2f".format(Locale.ROOT, fit.intercept))
    show("slope", "%.2f".format(Locale.ROOT, fit.slope))

    // Scatter by species plus the fitted line.
    plotFit(df, fit)
    show("plot", PLOT)

    // Both solvers must agree within 1e-8.
    val ok = fit.agrees(qr, tol = 1e-8)
    verdict(ok, "Simple vs QR")
    emitContract(
        "ads-kotlin-p2-v1",
        "simple vs QR slope %.2f".format(Locale.ROOT, fit.slope),
        ok,
    )
}
