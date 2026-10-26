package com.paiml.ads

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
    show("intercept", "%.2f".format(fit.intercept))
    show("slope", "%.2f".format(fit.slope))

    // Scatter by species plus the fitted line.
    plotFit(df, fit)
    show("plot", PLOT)

    // Both solvers must agree within 1e-8.
    verdict(fit.agrees(qr, tol = 1e-8), "Simple vs QR")
}
