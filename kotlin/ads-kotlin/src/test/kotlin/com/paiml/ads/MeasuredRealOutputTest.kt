package com.paiml.ads

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.File

/**
 * Runs only as task measuredCheck, on the captured output of the
 * live koverLog koverLogBranch tasks (scripts/gate-kotlin.sh).
 * A missing capture is a hard failure, never a skip.
 */
class MeasuredRealOutputTest {
    @Test
    fun everyKoverScenePatternMatchesTheRealOutput() {
        val path = System.getProperty("ads.koverOut").orEmpty()
        assertTrue(path.isNotBlank(), "ads.koverOut not set")
        val f = File(path)
        assertTrue(f.isFile, "no captured kover output: $path")
        val out = f.readText()
        assertTrue(
            "BUILD SUCCESSFUL" in out,
            "capture is not a run",
        )
        val dir = File(System.getProperty("ads.scenes"))
        val kover =
            dir.listFiles { s -> s.extension == "scene" }
                .orEmpty().sorted()
                .map { it.name to sceneKeys(it) }
                .filter { it.second["tool"] == "kover" }
        assertTrue(kover.isNotEmpty())
        val bad =
            kover.mapNotNull { (n, m) ->
                measuredProblem(m.getValue("measured"), out)
                    ?.let { "$n: $it" }
            }
        assertEquals(emptyList<String>(), bad)
    }
}
