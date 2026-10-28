package com.paiml.ads.m3v01

import com.paiml.ads.classify
import com.paiml.ads.cluster
import com.paiml.ads.emitContract
import com.paiml.ads.loadClean
import com.paiml.ads.matchesGolden
import com.paiml.ads.readCentroids
import com.paiml.ads.readSplit
import com.paiml.ads.show
import com.paiml.ads.verdict

fun main() {
    // The 342 clean rows, the fixed split and centroids.
    val df = loadClean()
    val split = readSplit()
    val start = readCentroids()

    // Gini tree: fit on train rows, score on test rows.
    val scored = classify(df, split)
    show("accuracy", "%.4f".format(scored.accuracy()))
    show("confusion", "${scored.confusion}")

    // Lloyd k-means from the fixed starting centroids.
    val km = cluster(df, start)
    show("objective", "%.4f".format(km.objective))
    show("sizes", "${km.sizes}")

    // Both models must reproduce the R golden.
    val ok = matchesGolden(scored, km)
    verdict(ok, "P3 matches golden")
    emitContract(
        "ads-kotlin-p3-v1",
        "accuracy %.4f objective %.4f".format(
            scored.accuracy(),
            km.objective,
        ),
        ok,
    )
}
