package com.paiml.ads

import org.jetbrains.kotlinx.dataframe.AnyFrame
import org.jetbrains.kotlinx.dataframe.DataFrame
import org.jetbrains.kotlinx.dataframe.api.dropNulls
import org.jetbrains.kotlinx.dataframe.io.readCsv
import org.jetbrains.kotlinx.kandy.dsl.categorical
import org.jetbrains.kotlinx.kandy.dsl.plot
import org.jetbrains.kotlinx.kandy.letsplot.export.save
import org.jetbrains.kotlinx.kandy.letsplot.feature.layout
import org.jetbrains.kotlinx.kandy.letsplot.layers.abLine
import org.jetbrains.kotlinx.kandy.letsplot.layers.points
import org.jetbrains.kotlinx.kandy.util.color.Color

/** Model columns, and the row count expected after dropping NA. */
const val FLIPPER = "flipper_length_mm"
const val MASS = "body_mass_g"
const val ROWS = 342
private const val PLOT_SCALE = 1.0
private const val POINT_SIZE = 8.0
private const val LINE_WIDTH = 3.0

/** Species colours: three hues that stay apart on a phone. */
private val SPECIES =
    listOf("#ff8c1a", "#4aa3ff", "#35c46b").map { Color.hex(it) }

/** Read the CSV and drop NA only in the two model columns. */
fun loadClean(): AnyFrame {
    val df = DataFrame.readCsv(PENGUINS).dropNulls(FLIPPER, MASS)
    expectRows(df.rowsCount(), ROWS)
    return df
}

/** Scatter coloured by species plus the fitted line, saved to PLOT. */
fun plotFit(
    df: AnyFrame,
    fit: Fit,
) {
    val chart =
        df.plot {
            points {
                x(FLIPPER)
                y(MASS)
                size = POINT_SIZE
                color("species") {
                    scale = categorical(range = SPECIES)
                }
            }
            abLine {
                intercept.constant(fit.intercept)
                slope.constant(fit.slope)
                width = LINE_WIDTH
                color = Color.hex("#222222")
            }
            layout { phoneStyle("Palmer penguins: OLS fit") }
        }
    chart.save(PLOT, scale = PLOT_SCALE, path = ".")
}
