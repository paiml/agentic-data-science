package com.paiml.ads

import com.github.ajalt.mordant.rendering.TextColors.cyan
import com.github.ajalt.mordant.rendering.TextColors.green
import com.github.ajalt.mordant.rendering.TextColors.red
import com.github.ajalt.mordant.terminal.Terminal
import org.jetbrains.kotlinx.kandy.letsplot.feature.Layout
import org.jetbrains.kotlinx.kandy.util.context.invoke
import java.util.Properties

private val term = Terminal()
private const val LABEL_WIDTH = 10
private const val TITLE_FONT = 28.0
private const val LABEL_FONT = 26.0
private const val TICK_FONT = 24.0
private const val CANVAS_W = 720
private const val CANVAS_H = 1080

/** Plot canvas for a phone: big pixels, big text. */
fun Layout.phoneStyle(title: String) {
    this.title = title
    size = CANVAS_W to CANVAS_H
    style {
        plotCanvas { title { fontSize = TITLE_FONT } }
        axis {
            title { fontSize = LABEL_FONT }
            text { fontSize = TICK_FONT }
        }
        legend {
            title { fontSize = LABEL_FONT }
            text { fontSize = LABEL_FONT }
        }
    }
}

/** Print the toolchain and pinned library versions once. */
fun showVersions() {
    val pins = Properties()
    object {}
        .javaClass
        .getResourceAsStream(
            "/versions.properties",
        ).use {
            pins.load(it)
        }
    val jvm = Runtime.version().feature()
    term.println(
        cyan("kotlin") + " ${KotlinVersion.CURRENT}  jvm $jvm",
    )
    term.println(cyan("dataframe") + " ${pins["dataframe"]}")
    term.println(
        cyan("kandy") + " ${pins["kandy"]}  " +
            cyan("mordant") + " ${pins["mordant"]}",
    )
    term.println(cyan("commons-math3") + " ${pins["commonsMath"]}")
}

/** One aligned label: value row. */
fun show(
    label: String,
    value: String,
) = term.println(cyan(label.padEnd(LABEL_WIDTH)) + ": " + value)

/** Verdict line: green on pass, red on fail. */
fun verdict(
    ok: Boolean,
    what: String,
): String {
    val line =
        if (ok) {
            green(
                "VERDICT: $what PASS",
            )
        } else {
            red("VERDICT: $what FAIL")
        }
    term.println(line)
    return line
}
