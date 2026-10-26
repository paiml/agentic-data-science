package com.paiml.ads

import java.io.File
import kotlin.math.abs

/** Rows in the raw CSV, and the golden tolerance. */
const val RAW_ROWS = 344
const val P1_TOL = 1e-6

/** Committed R golden for P1, found beside the dataset. */
val GOLDEN_P1: File =
    File(PENGUINS).absoluteFile.parentFile.parentFile
        .resolve("golden/p1.json")

private val NUMBER = Regex("""^\s*"(\w+)":\s*(-?[0-9.eE+-]+),?$""")
private val OPEN = Regex("""^\s*"(\w+)":\s*\{$""")

/** Golden leaves keyed like species/Adelie/n. */
fun goldenValues(file: File): Map<String, Double> {
    val path = ArrayDeque<String>()
    val out = linkedMapOf<String, Double>()
    file.forEachLine { line ->
        OPEN.find(line)?.let { path.addLast(it.groupValues[1]) }
        NUMBER.find(line)?.let {
            val key = (path + it.groupValues[1]).joinToString("/")
            out[key] = it.groupValues[2].toDouble()
        }
        if (line.trim().startsWith("}")) path.removeLastOrNull()
    }
    return out
}

/** The same keys (species/...) for a computed summary. */
fun summaryValues(rows: List<SpeciesSummary>): Map<String, Double> =
    rows.flatMap { s ->
        val p = "species/${s.species}"
        listOf("$p/n" to s.n.toDouble()) +
            MEASURES.flatMap { c ->
                listOf(
                    "$p/$c/mean" to s.mean.getValue(c),
                    "$p/$c/sd" to s.sd.getValue(c),
                )
            }
    }.toMap()

/** Largest |computed - golden|; infinite if the keys differ. */
fun goldenGap(
    rows: List<SpeciesSummary>,
    golden: File,
): Double {
    val want = goldenValues(golden)
    val got = summaryValues(rows)
    if (want.keys != got.keys) return Double.POSITIVE_INFINITY
    return want.maxOf { (k, v) -> abs(v - got.getValue(k)) }
}

/** One aligned species row: n, mean mass and mean flipper. */
fun showSpecies(s: SpeciesSummary) =
    show(
        s.species,
        "n=%d  mass %.1f g  flipper %.1f mm".format(
            s.n,
            s.mean.getValue("body_mass_g"),
            s.mean.getValue("flipper_length_mm"),
        ),
    )

/** True when 344 rows were read and 342 survive the policy. */
fun countsHold(
    read: List<Penguin>,
    kept: List<Penguin>,
) = read.size == RAW_ROWS && kept.size == ROWS

/** True when a golden gap is within the P1 tolerance. */
fun withinTol(gap: Double) = gap <= P1_TOL
