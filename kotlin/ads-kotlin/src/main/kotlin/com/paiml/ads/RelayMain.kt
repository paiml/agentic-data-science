package com.paiml.ads

import java.io.File

/** Contract line for a gradle task: tests, detekt or gate. */
fun relayLine(args: List<String>): String {
    return when (args.first()) {
        "tests" -> testsLine(File(args[1]))
        "detekt" ->
            detektLine(args[1].toBoolean(), File(args[2]))
        else ->
            gateLine(
                args[1].toBoolean(),
                File(args[2]),
                File(args.last()),
            )
    }
}

fun main(args: Array<String>) {
    val line = relayLine(args.toList())
    println(line)
    check(line.endsWith(" OK")) { line }
}
