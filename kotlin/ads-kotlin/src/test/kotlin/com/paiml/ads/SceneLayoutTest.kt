package com.paiml.ads

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.File

private const val MAX_LINES = 25
private const val MAX_COLS = 59
private const val MAX_RUN = 74
private const val WIRED_SHACL =
    "./gradlew --console=plain verifyShacl"
private const val EXIT_ECHO = "echo \"exit=\$?\""
private val RUNNERS =
    listOf("./gradlew ", "pmat ", "shacl ", "sha256sum ")
private val dir = File(System.getProperty("ads.scenes"))
private val srcDir = dir.parentFile

private fun manifest(f: File) =
    f.readLines().filter { "=" in it }.associate {
        it.substringBefore("=").trim() to
            it.substringAfter("=").trim()
    }

/** The shown lines of a scene: whole file or lines=a-b. */
fun shown(m: Map<String, String>): List<String> {
    val all = File(srcDir, m.getValue("file")).readLines()
    val (a, b) =
        (m["lines"] ?: "1-${all.size}").split(
            "-",
        ).map { it.toInt() }
    return all.subList(a - 1, b)
}

/** Bracket depth before each line of [text]. */
fun depths(text: List<String>): List<Int> {
    var d = 0
    return text.map { line ->
        val before = d
        d += line.count { it in "([{" } - line.count { it in ")]}" }
        before
    }
}

fun spans(s: String) =
    s.split(",").map { p ->
        p.split("-").map { it.toInt() }.let { it[0] to it.last() }
    }

class SceneLayoutTest {
    private val files =
        dir.listFiles {
                f ->
            f.extension == "scene"
        }.orEmpty().sorted()

    @Test
    fun everySceneFitsTheLayout() {
        assertTrue(files.isNotEmpty())
        files.forEach { f ->
            val m = manifest(f)
            val text = shown(m)
            val name = f.name
            assertTrue(text.size <= MAX_LINES, "$name lines")
            assertTrue(
                text.all { it.length <= MAX_COLS },
                "$name cols",
            )
            assertTrue(text.none { '\\' in it || '\t' in it }, name)
        }
    }

    @Test
    fun ticksAreWholeStatements() {
        files.forEach { f ->
            val m = manifest(f)
            val text = shown(m)
            val d = depths(text)
            val ticks = spans(m.getValue("ticks"))
            assertEquals(1, ticks.first().first, f.name)
            assertEquals(text.size, ticks.last().second, f.name)
            ticks.zipWithNext().forEach { (a, b) ->
                assertEquals(a.second + 1, b.first, f.name)
                assertEquals(
                    0,
                    d[b.first - 1],
                    "${f.name} ${b.first}",
                )
            }
        }
    }

    @Test
    fun everyManifestNamesAFileAndARunLine() {
        files.forEach { f ->
            val m = manifest(f)
            assertTrue(
                File(srcDir, m.getValue("file")).isFile,
                f.name,
            )
            assertTrue(
                RUNNERS.any { m.getValue("run").startsWith(it) } ||
                    "tool" in m,
                f.name,
            )
            assertTrue(m.getValue("ready").isNotBlank(), f.name)
        }
    }
}

class SceneRulingsTest {
    private val files =
        dir.listFiles {
                f ->
            f.extension == "scene"
        }.orEmpty().sorted()

    @Test
    fun everyManifestHasLinesAndAnEndingOnAStatement() {
        files.forEach { f ->
            val m = manifest(f)
            assertTrue("lines" in m, "${f.name} lines key")
            val text = shown(m)
            assertEquals(0, depths(text + "").last(), f.name)
        }
    }

    @Test
    fun runLinesFitTheFrameAndNameAToolNotAWrapper() {
        files.forEach { f ->
            val run = manifest(f).getValue("run")
            assertTrue(run.length <= MAX_RUN, "${f.name} run cols")
            assertTrue(
                RUNNERS.any { run.startsWith(it) },
                "${f.name} runner",
            )
            assertFalse("make" in run || "scripts/" in run, f.name)
        }
    }

    @Test
    fun toolScenesShowTheNativeLineAndTheExitLine() {
        val tools = files.map { it.name to manifest(it) }
        tools.filter { "tool" in it.second }.forEach { (n, m) ->
            assertEquals(EXIT_ECHO, m["after"], "$n after")
            assertEquals("exit=0", m["exit"], "$n exit")
            val run = m.getValue("run")
            assertFalse(" -q" in run, "$n -q hides the tool line")
            if (m["tool"] == "shacl") {
                assertTrue(run.startsWith(WIRED_SHACL), n)
            }
            if (run.startsWith("./gradlew")) {
                assertTrue("--console=plain" in run, n)
                assertEquals("BUILD SUCCESSFUL", m["ready"], n)
            }
            assertFalse(
                m.getValue("ready").startsWith("exit="),
                "$n ready",
            )
        }
    }

    @Test
    fun noPlotScenesLogTheOpenRule() {
        files.map { it.name to manifest(it) }
            .filter { it.second["plot"] == "none" }
            .forEach { (n, m) ->
                val want =
                    if ("tool" in m) {
                        "tool-scene-rule"
                    } else {
                        "project-scene-rule"
                    }
                assertTrue(
                    want in m.getValue("open_rule"),
                    "$n open_rule",
                )
            }
    }

    @Test
    fun koverScenesPrintTheMeasuredNumber() {
        files.map { it.name to manifest(it) }
            .filter { it.second["tool"] == "kover" }
            .forEach { (n, m) ->
                val run = m.getValue("run")
                assertTrue("koverLog" in run, n)
                assertTrue("koverLogBranch" in run, n)
                assertTrue("koverVerify" in run, n)
                assertTrue("measured" in m, n)
            }
    }
}

class ShownRegionTest {
    @Test
    fun everyRegionStartsAndEndsOnADeclaration() {
        val bad = mutableListOf<String>()
        dir.listFiles { f -> f.extension == "scene" }.orEmpty()
            .sorted().forEach { f ->
                val m = manifest(f)
                val all =
                    File(
                        srcDir,
                        m.getValue("file"),
                    ).readLines()
                val (a, b) =
                    (m["lines"] ?: "1-${all.size}")
                        .split("-").map { it.toInt() }
                if (m.getValue(
                        "file",
                    ).endsWith(".csv")
                ) {
                    return@forEach
                }
                if (a != 1 && !opens(all[a - 2])) {
                    bad += "${f.name} starts mid-statement"
                }
                if (b != all.size && !closes(all[b])) {
                    bad += "${f.name} ends mid-statement"
                }
            }
        assertEquals(emptyList<String>(), bad)
    }
}

/** A shown region may start after a blank line or a body brace. */
private fun opens(prev: String) =
    prev.isBlank() || prev.trimEnd().endsWith("{")

/** A shown region may end before a blank line or a body brace. */
private fun closes(next: String) =
    next.isBlank() || next.trim() == "}"
