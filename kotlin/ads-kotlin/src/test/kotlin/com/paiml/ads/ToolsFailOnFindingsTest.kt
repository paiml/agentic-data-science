package com.paiml.ads

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.File

private val kotlinRoot =
    File(System.getProperty("ads.root"), "kotlin")
private val gradleBin = System.getProperty("ads.gradle")

// 71 columns, one declaration: only max-line-length can fire.
private val LONG_LINE =
    "val longName = \"${"a".repeat(54)}\"\n"
private const val CLEAN = "fun ok(a: Int) = a + 1\n"
private const val UNUSED = "private fun unused() {}\n\n$CLEAN"
private const val BRANCHY =
    "fun pick(a: Int) = if (a > 0) 1 else 2\n"

private const val ONE_SIDE =
    "import org.junit.jupiter.api.Test\n\nclass FailTest {\n" +
        "    @Test\n    fun covers() { pick(1) }\n}\n"

private fun failing(ok: Boolean) =
    "import org.junit.jupiter.api.Assertions.assertEquals\n" +
        "import org.junit.jupiter.api.Test\n\nclass FailTest {\n" +
        "    @Test\n    fun asserts() {\n" +
        "        assertEquals(1, ${if (ok) 1 else 2})\n    }\n}\n"

private fun has(
    out: String,
    text: String,
) = assertTrue(text in out, out)

private fun exec(
    dir: File,
    vararg cmd: String,
): Pair<Int, String> {
    val p =
        ProcessBuilder(*cmd).directory(dir)
            .redirectErrorStream(true).start()
    val out = p.inputStream.bufferedReader().readText()
    return p.waitFor() to out
}

private val CONTRACT_APPLY =
    Regex(
        """\n*// Contract line for the gradle[^\n]*\n""" +
            """apply\(from = "contract.gradle.kts"\)\n?""",
    )

private val SHACL_APPLY =
    Regex(
        """\n*// The wired shacl[^\n]*\n""" +
            """apply\(from = "shacl.gradle.kts"\)\n?""",
    )

/** A copy of the build (no tests) with one source. */
private fun buildCopy(
    source: String,
    test: String? = null,
): File {
    val tmp = TempTrash.dir("ads-tools")
    listOf(
        "gradle",
        "settings.gradle.kts",
        "gradle.properties",
        ".editorconfig",
        "build.gradle.kts",
        "ads-kotlin/build.gradle.kts",
        "ads-kotlin/detekt.yml",
    ).forEach {
        File(kotlinRoot, it).copyRecursively(File(tmp, it))
    }
    // Tool copies have no repo tree; the shacl gate is tested apart.
    val gb = File(tmp, "ads-kotlin/build.gradle.kts")
    val stripped = gb.readText().replace(SHACL_APPLY, "\n")
    val bare = stripped.replace(CONTRACT_APPLY, "\n")
    check(stripped != gb.readText()) { "no shacl apply line" }
    check(bare != stripped) { "no contract apply line" }
    gb.writeText(bare)
    val src = File(tmp, "ads-kotlin/src/main/kotlin")
    src.mkdirs()
    File(src, "Source.kt").writeText(source)
    if (test != null) {
        val t = File(tmp, "ads-kotlin/src/test/kotlin")
        t.mkdirs()
        File(t, "FailTest.kt").writeText(test)
    }
    return tmp
}

private fun gradle(
    copy: File,
    vararg tasks: String,
) = exec(
    copy,
    gradleBin,
    "--offline",
    "--no-daemon",
    "--console=plain",
    *tasks,
)

/**
 * Each gate tool, run live on a planted violation in
 * a copy of the build, fails it; the same copy without the
 * violation passes. The tool decides, never the test.
 */
class ToolsFailOnFindingsTest {
    @Test
    fun ktlintFailsOnALongLineAndPassesWhenItIsFixed() {
        val bad = gradle(buildCopy(LONG_LINE), "ktlintCheck")
        assertNotEquals(0, bad.first, bad.second)
        has(bad.second, "Exceeded max line length (68)")
        val ok = gradle(buildCopy(CLEAN), "ktlintCheck")
        assertEquals(0, ok.first, ok.second)
    }

    @Test
    fun detektFailsOnAnUnusedMemberAndPassesWhenItIsFixed() {
        val bad = gradle(buildCopy(UNUSED), "detekt")
        assertNotEquals(0, bad.first, bad.second)
        has(bad.second, "UnusedPrivate")
        val ok = gradle(buildCopy(CLEAN), "detekt")
        assertEquals(0, ok.first, ok.second)
    }

    @Test
    fun koverBranchRuleFailsWithFullLineCoverage() {
        val copy = buildCopy(BRANCHY, ONE_SIDE)
        val r =
            gradle(
                copy,
                "--continue",
                "koverLog",
                "koverLogBranch",
                "koverVerify",
            )
        assertNotEquals(0, r.first, r.second)
        val out = r.second
        has(out, "line coverage 100% (koverVerify bound: 100%)")
        has(out, "branch coverage 50% (koverVerify bound: 95%)")
        has(out, "branches covered percentage")
        assertFalse("lines covered percentage" in out, out)
    }

    @Test
    fun koverVerifyFailsWhenTheCodeIsNotCovered() {
        val bad = gradle(buildCopy(CLEAN), "koverVerify")
        assertNotEquals(0, bad.first, bad.second)
        has(bad.second, "lines covered percentage")
    }

    @Test
    fun testTaskFailsOnAFailingAssertion() {
        val bad = gradle(buildCopy(CLEAN, failing(false)), "test")
        assertNotEquals(0, bad.first, bad.second)
        has(bad.second, "FailTest")
        val copy = buildCopy(CLEAN, failing(true))
        val ok = gradle(copy, "test")
        assertEquals(0, ok.first, ok.second)
        val xml =
            File(
                copy,
                "ads-kotlin/build/test-results/test/" +
                    "TEST-FailTest.xml",
            )
        assertTrue("tests=\"1\"" in xml.readText())
    }

    @Test
    fun pmatFailsOnAComplexFunctionAndPassesWhenItIsFixed() {
        val tmp = TempTrash.dir("ads-pmat")
        val body =
            (1..40).joinToString("\n") {
                "    if (a == $it) r += $it"
            }
        File(tmp, "G.kt").writeText(
            "fun g(a: Int): Int {\n    var r = 0\n" +
                "$body\n    return r\n}\n",
        )
        val bad =
            exec(
                tmp,
                "pmat",
                "quality-gate",
                "--checks",
                "complexity",
            )
        assertNotEquals(0, bad.first, bad.second)
        has(bad.second, "cyclomatic-complexity")
        File(tmp, "G.kt").writeText(CLEAN)
        val ok =
            exec(
                tmp,
                "pmat",
                "quality-gate",
                "--checks",
                "complexity",
            )
        assertEquals(0, ok.first, ok.second)
    }
}
