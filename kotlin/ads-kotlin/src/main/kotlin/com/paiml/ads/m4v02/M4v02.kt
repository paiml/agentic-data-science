package com.paiml.ads.m4v02

import com.paiml.ads.RED
import com.paiml.ads.WHITE
import com.paiml.ads.aggregateFrame
import com.paiml.ads.aggregatePlain
import com.paiml.ads.benchWine
import com.paiml.ads.emitContract
import com.paiml.ads.enginesAgree
import com.paiml.ads.readWine
import com.paiml.ads.show
import com.paiml.ads.validate
import com.paiml.ads.verdict

fun main() {
    // Two engines aggregate the same wine table.
    val wine = validate(readWine(RED, WHITE))
    val frame = aggregateFrame(wine)
    val plain = aggregatePlain(wine)
    frame.forEach { (c, v) -> show(c, "${v.second} rows") }

    // Agreement first: a fast wrong answer is worthless.
    val agree = enginesAgree(frame, plain)
    show("agree", "$agree")

    // Only then time them; print the count, not the clock.
    val secs = if (agree) benchWine(wine) else emptyMap()
    show("timed", "${secs.size} engines")

    val live =
        secs.isNotEmpty() && secs.values.all { it > 0 }
    val ok = agree && live
    verdict(ok, "P4 bench")
    emitContract(
        "ads-kotlin-examples-m4-v1",
        "engines agree, timed ${secs.size}",
        ok,
    )
}
