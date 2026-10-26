package com.paiml.ads

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.File

private val scenesDir = File(System.getProperty("ads.scenes"))

/** The ONE recorder base: the repo root (scenes/CONTRACT.md). */
private val base = File(System.getProperty("ads.root"))

fun sceneKeys(f: File) =
    f.readLines().filter { "=" in it }.associate {
        it.substringBefore("=").trim() to
            it.substringAfter("=").trim()
    }

private fun scenes() =
    scenesDir.listFiles { f -> f.extension == "scene" }
        .orEmpty().sorted().map { it.name to sceneKeys(it) }

/** Why a scene's cwd is wrong when resolved from [root]. */
fun cwdProblem(
    root: File,
    m: Map<String, String>,
): String? {
    val c = m["cwd"].orEmpty()
    val d = File(root, c)
    val run = m.getValue("run")
    val sums = run.removePrefix("sha256sum -c ").trim()
    return listOf(
        "no cwd key" to c.isBlank(),
        "cwd $c is not relative to the base" to
            (c.startsWith("/") || ".." in c.split("/")),
        "cwd $c is not a directory" to !d.isDirectory,
        "no executable gradlew in $c" to
            (
                run.startsWith("./gradlew") &&
                    !File(d, "gradlew").canExecute()
            ),
        "no $sums in $c" to
            (
                run.startsWith("sha256sum -c ") &&
                    !File(d, sums).isFile
            ),
    ).firstOrNull { it.second }?.first
}

private const val SHAPE =
    "^(line coverage 100% \\(koverVerify bound: 100%\\)|" +
        "branch coverage (9[5-9]|100)(\\.[0-9]+)?% " +
        "\\(koverVerify bound: 95%\\))$"

/** Why [pattern] does not prove the line AND branch numbers. */
fun measuredProblem(
    pattern: String,
    out: String,
): String? {
    val hits =
        Regex(pattern, RegexOption.MULTILINE).findAll(out)
            .map { it.value }.toList()
    val shown =
        out.lines().filter {
            it.startsWith("line coverage ") ||
                it.startsWith("branch coverage ")
        }
    val problem =
        when {
            hits.count { it.startsWith("line coverage ") } != 1 ->
                "no single line-coverage hit: $hits"
            hits.count { it.startsWith("branch coverage ") } != 1 ->
                "no single branch-coverage hit: $hits"
            shown.any { it !in hits } ->
                "unmatched number on screen: $shown"
            else -> null
        }
    return problem
}

private const val REAL =
    "kover\nline coverage 100% (koverVerify bound: 100%)\n\n" +
        "kover\nbranch coverage 95.2381% (koverVerify bound: 95%)\n"

/** Every scene names a cwd that exists under the one base. */
class SceneCwdTest {
    @Test
    fun theBaseIsTheRepoRoot() {
        assertTrue(File(base, "kotlin/gradlew").isFile)
        assertTrue(File(base, "datasets/penguins").isDirectory)
        assertTrue(File(base, "Makefile").isFile)
    }

    @Test
    fun everySceneCwdResolvesFromTheBase() {
        assertTrue(scenes().isNotEmpty())
        val bad =
            scenes().mapNotNull { (n, m) ->
                cwdProblem(base, m)?.let { "$n: $it" }
            }
        assertEquals(emptyList<String>(), bad)
    }

    @Test
    fun aBadCwdFails() {
        val ok = mapOf("cwd" to "kotlin", "run" to "./gradlew x")
        assertNull(cwdProblem(base, ok))
        listOf(
            ok - "cwd",
            ok + ("cwd" to "nope"),
            ok + ("cwd" to "kotlin/ads-kotlin"),
            ok + ("cwd" to "../kotlin"),
            ok + ("cwd" to "$base/kotlin"),
            ok + ("cwd" to "kotlin/gradle.properties"),
        ).forEach { assertNotNull(cwdProblem(base, it), "$it") }
        val sums =
            mapOf(
                "cwd" to "kotlin",
                "run" to "sha256sum -c SHA256SUMS",
            )
        assertNotNull(cwdProblem(base, sums))
        assertNull(
            cwdProblem(base, sums + ("cwd" to "datasets/penguins")),
        )
    }
}

/** `measured` is a regex that proves the line AND branch numbers. */
class SceneMeasuredTest {
    private val koverScenes =
        scenes().filter { it.second["tool"] == "kover" }

    @Test
    fun everyKoverSceneHasAPatternThatMatchesTheRealShape() {
        assertTrue(koverScenes.isNotEmpty())
        koverScenes.forEach { (n, m) ->
            assertEquals(SHAPE, m["measured"], n)
            assertNull(
                measuredProblem(m.getValue("measured"), REAL),
            )
        }
    }

    @Test
    fun aWrongNumberFails() {
        val p = SHAPE
        listOf(
            REAL.replace("100% (", "99% ("),
            REAL.replace("95.2381%", "94.9%"),
            REAL.replace("95.2381%", "50%"),
            REAL.replace("bound: 95%", "bound: 90%"),
            REAL.replace("bound: 100%", "bound: 90%"),
            REAL.replace("branch coverage", "branch cover"),
            REAL.substringBefore("\nbranch"),
            REAL.replace("100% (", "100%  ("),
        ).forEach { assertNotNull(measuredProblem(p, it), it) }
    }

    @Test
    fun aPatternForAnotherNumberFails() {
        val hard = "^branch coverage 97% .*$|^line coverage 100.*$"
        assertNotNull(measuredProblem(hard, REAL))
        assertNotNull(
            measuredProblem("^line coverage 100.*$", REAL),
        )
    }
}
