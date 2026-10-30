package com.paiml.ads.m4v01

import com.paiml.ads.RED
import com.paiml.ads.WHITE
import com.paiml.ads.emitContract
import com.paiml.ads.matchesGolden
import com.paiml.ads.readWine
import com.paiml.ads.scoreWine
import com.paiml.ads.show
import com.paiml.ads.splitWine
import com.paiml.ads.validate
import com.paiml.ads.verdict

/**
 * Provable contract: ads-kotlin-examples-m4-v1, printed only after the check passes.
 */
fun main() {
    // Read both colours; validate before anything else.
    val wine = validate(readWine(RED, WHITE))
    show("rows", "${wine.rows}")

    // Every fifth row is a test row the model never sees.
    val split = splitWine(wine)
    show("train", "${split.train.rows}")
    show("test", "${split.test.rows}")

    // Fit on train rows only, score on the held-out rows.
    val score = scoreWine(split)
    show("rmse", "%.6f".format(score.rmse))
    show("r2", "%.6f".format(score.r2))

    // Must match the R oracle (golden) within 1e-6.
    val ok = matchesGolden(wine, split, score)
    verdict(ok, "P4 vs golden")
    emitContract(
        "ads-kotlin-examples-m4-v1",
        "rmse %.6f r2 %.6f".format(score.rmse, score.r2),
        ok,
    )
}
