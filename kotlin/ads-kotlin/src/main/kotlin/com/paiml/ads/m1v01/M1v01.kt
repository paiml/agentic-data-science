package com.paiml.ads.m1v01

import com.paiml.ads.PENGUINS
import com.paiml.ads.countsHold
import com.paiml.ads.emitContract
import com.paiml.ads.naPolicy
import com.paiml.ads.readPenguins
import com.paiml.ads.show
import com.paiml.ads.verdict

fun main() {
    // Typed read: NA is a null, never a sentinel.
    val rows = readPenguins(PENGUINS)
    show("rows read", "${rows.size}")

    // NA policy: drop rows missing a measurement.
    val kept = naPolicy(rows)
    show("rows kept", "${kept.size}")

    // The counts are the contract: 344 in, 342 kept.
    val ok = countsHold(rows, kept)
    verdict(ok, "ingest 344 -> 342")
    emitContract(
        "ads-kotlin-examples-m1-v1",
        "rows ${rows.size} -> ${kept.size}",
        ok,
    )
}
