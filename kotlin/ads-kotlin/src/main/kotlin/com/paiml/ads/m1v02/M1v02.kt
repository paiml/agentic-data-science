package com.paiml.ads.m1v02

import com.paiml.ads.GOLDEN_P1
import com.paiml.ads.PENGUINS
import com.paiml.ads.goldenGap
import com.paiml.ads.naPolicy
import com.paiml.ads.readPenguins
import com.paiml.ads.show
import com.paiml.ads.showSpecies
import com.paiml.ads.summariseBySpecies
import com.paiml.ads.verdict
import com.paiml.ads.withinTol

fun main() {
    // Ingest, then profile each species.
    val kept = naPolicy(readPenguins(PENGUINS))
    val rows = summariseBySpecies(kept)
    rows.forEach { showSpecies(it) }

    // Compare every number with the committed R golden.
    val gap = goldenGap(rows, GOLDEN_P1)
    show("max gap", "%.2e".format(gap))
    verdict(withinTol(gap), "profile matches R golden")
}
