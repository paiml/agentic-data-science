package com.paiml.ads

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.File

private val kotlinDir =
    File(System.getProperty("ads.scripts"))
private val build = File(kotlinDir, "build.gradle.kts").readText()
private val detekt = File(kotlinDir, "detekt.yml").readText()
private val shacl = File(kotlinDir, "shacl.gradle.kts").readText()

/** The tools must fail on findings: the wiring says how. */
class BuildWiringTest {
    @Test
    fun noToolIsAllowedToIgnoreFailures() {
        assertFalse("ignoreFailures" in build)
        assertFalse("ignoreFailures" in shacl)
        assertFalse("isIgnoreExitValue" in shacl)
    }

    @Test
    fun detektFailsOnTheFirstIssue() {
        assertTrue(
            "maxIssues" !in detekt,
        )
    }

    @Test
    fun koverBoundsAreLine100AndBranch95() {
        assertTrue("minBound(lineBound)" in build)
        assertTrue("val lineBound = 100\n" in build)
        assertFalse("findProperty" in build)
        assertTrue("bound: \$lineBound%" in build)
        assertTrue("bound: \$branchBound%" in build)
        assertTrue("useJUnitPlatform()" in build)
        assertTrue("val branchBound = 95" in build)
        assertTrue("minValue = branchBound" in build)
        assertTrue("CoverageUnit.BRANCH" in build)
    }

    @Test
    fun noFixedPassLineIsPrintedByTheBuild() {
        val printed = Regex("""println\(""").findAll(build).count()
        assertEquals(0, printed)
        assertFalse("doLast" in build)
        assertFalse("println(" in shacl)
        assertFalse("System.out" in shacl)
        assertTrue("verifyShaclAll" in shacl)
        for (banned in listOf(
            "shaclRepo",
            "shaclTable",
            "findProperty",
            "extra.properties",
            "gradleProperty",
            "property(",
            "providers.",
            "hasProperty",
            "properties[",
            "getenv",
            "System.getProperty",
            "by project",
            "extra[",
        )) {
            assertFalse(banned in shacl, banned)
        }
        assertFalse(
            Regex(
                "(?i)propert|getenv|System\\.get",
            ).containsMatchIn(shacl),
        )
    }
}
