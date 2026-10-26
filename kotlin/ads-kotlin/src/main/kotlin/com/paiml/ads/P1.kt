package com.paiml.ads

import org.jetbrains.kotlinx.dataframe.DataFrame
import org.jetbrains.kotlinx.dataframe.annotations.ColumnName
import org.jetbrains.kotlinx.dataframe.annotations.DataSchema
import org.jetbrains.kotlinx.dataframe.api.cast
import org.jetbrains.kotlinx.dataframe.api.rows
import org.jetbrains.kotlinx.dataframe.io.readCsv
import kotlin.math.sqrt

/** Measurement columns, in golden order. */
val MEASURES: List<String> =
    listOf(
        "bill_length_mm",
        "bill_depth_mm",
        "flipper_length_mm",
        "body_mass_g",
    )

/** Typed schema of penguins.csv; NA is null. */
@DataSchema
interface PenguinRow {
    val species: String

    @ColumnName("bill_length_mm")
    val billLengthMm: Double?

    @ColumnName("bill_depth_mm")
    val billDepthMm: Double?

    @ColumnName("flipper_length_mm")
    val flipperLengthMm: Int?

    @ColumnName("body_mass_g")
    val bodyMassG: Int?
}

data class Penguin(
    val species: String,
    val billLengthMm: Double?,
    val billDepthMm: Double?,
    val flipperLengthMm: Double?,
    val bodyMassG: Double?,
) {
    fun measures(): List<Double?> =
        listOf(
            billLengthMm,
            billDepthMm,
            flipperLengthMm,
            bodyMassG,
        )
}

data class SpeciesSummary(
    val species: String,
    val n: Int,
    val mean: Map<String, Double>,
    val sd: Map<String, Double>,
)

/** Read penguins.csv with a typed schema; NA is null. */
fun readPenguins(path: String): List<Penguin> {
    val df: DataFrame<PenguinRow> =
        DataFrame.readCsv(
            path,
        ).cast(verify = true)
    return df.rows().map { r ->
        Penguin(
            r["species"] as String,
            r["bill_length_mm"].num(),
            r["bill_depth_mm"].num(),
            r["flipper_length_mm"].num(),
            r["body_mass_g"].num(),
        )
    }
}

/** Cell as a Double; null stays null. */
private fun Any?.num() = (this as Number?)?.toDouble()

/**
 * Drop a row iff a numeric measurement is null or NaN.
 * Sex is not read, so a missing sex cannot drop a row.
 */
fun naPolicy(rows: List<Penguin>): List<Penguin> =
    rows.filter {
            p ->
        p.measures().all { it != null && !it.isNaN() }
    }

private fun mean(xs: List<Double>) = xs.sum() / xs.size

private fun sampleSd(xs: List<Double>): Double {
    if (xs.size < 2) return Double.NaN
    val m = mean(xs)
    val ss = xs.sumOf { (it - m) * (it - m) }
    return sqrt(ss / (xs.size - 1))
}

/**
 * Count, mean and sample SD (n-1) of each measure,
 * per species, species sorted.
 */
fun summariseBySpecies(rows: List<Penguin>) =
    rows.groupBy { it.species }.toSortedMap().map {
            (species, group) ->
        val cols =
            MEASURES.indices.map {
                    i ->
                group.mapNotNull { it.measures()[i] }
            }
        SpeciesSummary(
            species,
            group.size,
            MEASURES.zip(cols.map(::mean)).toMap(),
            MEASURES.zip(cols.map(::sampleSd)).toMap(),
        )
    }

/** Serialise the species profile to the golden layout. */
fun profileJson(path: String): String {
    val body =
        summariseBySpecies(
            naPolicy(readPenguins(path)),
        ).joinToString(",\n") { s ->
            val cols =
                MEASURES.joinToString(",") { c ->
                    val m = s.mean[c]
                    val sd = s.sd[c]
                    "\"$c\":{\"mean\":$m,\"sd\":$sd}"
                }
            "\"${s.species}\":{\"n\":${s.n},$cols}"
        }
    return "{\"species\":{\n$body\n}}"
}
